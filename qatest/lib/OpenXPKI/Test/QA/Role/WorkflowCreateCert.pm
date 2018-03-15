package OpenXPKI::Test::QA::Role::WorkflowCreateCert;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::QA::Role::Workflows - Moose role that extends L<OpenXPKI::Test>
with a quick way to create certificates

=head1 DESCRIPTION

Please note that this role requires two other roles to be applied:
L<OpenXPKI::Test::QA::Role::SampleConfig> and
L<OpenXPKI::Test::QA::Role::Workflows>, i.e.:

    my $oxitest = OpenXPKI::Test->new(
        with => [ qw( SampleConfig Workflow WorkflowCreateCert ],
        ...
    );

=cut

# CPAN modules
use Test::More;
use Test::Exception;

# Project modules
use OpenXPKI::Server::Context;
use OpenXPKI::Test::QA::Role::Workflows::CertParams;
use OpenXPKI::Serialization::Simple;


requires 'also_init';
requires 'default_realm';   # effectively requires 'OpenXPKI::Test::QA::Role::SampleConfig'
                            # we can't use with '...' because if other roles also said that then it would be applied more than once
requires 'create_workflow'; # effectively requires 'OpenXPKI::Test::QA::Role::Workflows'
requires 'session';


before 'init_server' => sub {
    my $self = shift;
    # prepend to existing array in case a user supplied "also_init" needs our modules
    unshift @{ $self->also_init }, 'crypto_layer', 'volatile_vault';
};

=head1 METHODS

This role adds the following methods to L<OpenXPKI::Test>:

=head2 create_cert

Runs a L<lives_ok|Test::Exception/lives_ok> test that creates a certificate via
API by starting the workflow I<certificate_signing_request_v2>.

Returns a I<HashRef> with some certificate info:

    {
        req_key    => ...,
        identifier => ...,
        profile    => ...,
    }

Please note that if used in conjunction with L<OpenXPKI::Test::QA::Role::Server>
the workflow is still directly created by accessing the API methods, i.e. there
is NO socket communication to the running server daemon.

=cut
sub create_cert {
    my ($self, @args) = @_;

    my $params = OpenXPKI::Test::QA::Role::Workflows::CertParams->new(@args);

    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $is_server_profile = $params->profile eq "I18N_OPENXPKI_PROFILE_TLS_SERVER";
    my $is_client_profile = $params->profile eq "I18N_OPENXPKI_PROFILE_TLS_CLIENT";

    my %cert_subject_parts = (
        # IP addresses instead of host names will make DNS lookups fail quicker
        hostname => $params->hostname,
        $is_server_profile ? (
            hostname2 => $params->hostname2,
            port => 8080,
        ) : (),
        $is_client_profile ? (
            application_name => $params->application_name,
        ) : (),
    );

    my $cert_info = {};

    subtest "Create certificate (hostname ".$params->hostname.")" => sub {
        # change PKI realm, user and role to get permission to create workflow
        my $sess_data = $self->session->data;
        my $old_realm = $sess_data->has_pki_realm ? $sess_data->pki_realm : undef;
        my $old_user =  $sess_data->has_user      ? $sess_data->user : undef;
        my $old_role =  $sess_data->has_role      ? $sess_data->role : undef;
        $sess_data->pki_realm($self->default_realm);
        $sess_data->user('raop');
        $sess_data->role('RA Operator');

        my $result;
        lives_and {
            my $wftest = $self->create_workflow(
                "certificate_signing_request_v2" => {
                    cert_profile => $params->profile,
                    cert_subject_style => "00_basic_style",
                }
            );

            $wftest->start_activity(
                'SETUP_REQUEST_TYPE',
                csr_provide_server_key_params => {
                    key_alg => "rsa",
                    enc_alg => 'aes256',
                    key_gen_params => $serializer->serialize( { KEY_LENGTH => 2048 } ),
                    password_type => 'client',
                    csr_type => 'pkcs10'
                },
            );

            $wftest->start_activity(
                'ENTER_KEY_PASSWORD',
                csr_ask_client_password => { _password => "m4#bDf7m3abd" },
            );

            $wftest->start_activity(
                'ENTER_SUBJECT',
                csr_edit_subject => {
                    cert_subject_parts => $serializer->serialize( \%cert_subject_parts ),
                },
            );

            if ($is_server_profile) {
                $wftest->start_activity(
                    'ENTER_SAN',
                    csr_edit_san => {
                        cert_san_parts => $serializer->serialize( { } ),
                    },
                );
            }

            $wftest->start_activity(
                'ENTER_CERT_INFO',
                'csr_edit_cert_info' => {
                    cert_info => $serializer->serialize( {
                        requestor_gname => $params->requestor_gname,
                        requestor_name  => $params->requestor_name,
                        requestor_email => $params->requestor_email,
                    } )
                },
            );

            $wftest->state_is('SUBJECT_COMPLETE') or BAIL_OUT;

            # Test FQDNs should not validate so we need a policy exception request
            # (on rare cases the responsible router might return a valid address, so we check)
            my $msg = $self->api_command(
                get_workflow_info => { ID => $wftest->id }
            );

            my $actions = $msg->{STATE}->{option};
            my $intermediate_state;
            if (grep { /^csr_enter_policy_violation_comment$/ } @$actions) {
                diag "Test FQDNs do not resolve - handling policy violation" if $ENV{TEST_VERBOSE};
                $wftest->start_activity(
                    undef,
                    csr_enter_policy_violation_comment => { policy_comment => 'This is just a test' },
                );
                $intermediate_state = 'PENDING_POLICY_VIOLATION';
            }
            else {
                diag "For whatever reason test FQDNs do resolve - submitting request" if $ENV{TEST_VERBOSE};
                $wftest->start_activity(
                    undef,
                    csr_submit => {},
                );
                $intermediate_state = 'PENDING';
            }

    #        if ($self->notbefore) {
    #            $test->execute_ok('csr_edit_validity', {
    #                notbefore => $self->notbefore,
    #                notafter => $self->notafter,
    #            });
    #            $test->state_is( ??? );
    #        }

            $wftest->start_activity(
                $intermediate_state,
                csr_approve_csr => {},
            );
            $wftest->state_is('SUCCESS') or BAIL_OUT;

            my $temp = $self->api_command(
                get_workflow_info => { ID => $wftest->id }
            );
            $cert_info = {
                req_key    => $temp->{WORKFLOW}->{CONTEXT}->{csr_serial},
                identifier => $temp->{WORKFLOW}->{CONTEXT}->{cert_identifier},
                profile    => $temp->{WORKFLOW}->{CONTEXT}->{cert_profile},
            };
        } "successfully run workflow";
        if ($old_realm) { $sess_data->pki_realm($old_realm) } else { $sess_data->clear_pki_realm }
        if ($old_user)  { $sess_data->user($old_user) }       else { $sess_data->clear_user }
        if ($old_role)  { $sess_data->role($old_role) }       else { $sess_data->clear_role }
    };

    return $cert_info;
}

1;
