package OpenXPKI::Test::Role::WithWorkflows;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::Role::WithWorkflows - Moose role that extends L<OpenXPKI::Test> to
prepare the test server for workflow execution.

=cut

# CPAN modules
use Test::More;
use Test::Exception;

# Project modules
use OpenXPKI::Server::Context;
use OpenXPKI::Test::Role::WithWorkflows::Definition;
use OpenXPKI::Test::Role::WithWorkflows::CertParams;
use OpenXPKI::Serialization::Simple;


requires '_build_default_tasks';
requires 'setup_env';
requires 'realm_config';
requires 'get_default_realm';


has _last_api_result => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    default => sub { {} },
);
has _workflow_id => (
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
);


around '_build_default_tasks' => sub {
    my $orig = shift;
    my $self = shift;

    return [ @{ $self->$orig }, 'workflow_factory', 'crypto_layer', 'volatile_vault' ];
};

before 'setup_env' => sub {
    my $self = shift;

    my $realm = $self->get_default_realm;

    $self->realm_config($realm, "workflow.global.action",
        OpenXPKI::Test::Role::WithWorkflows::Definition->global_action);
    $self->realm_config($realm, "workflow.global.condition",
        OpenXPKI::Test::Role::WithWorkflows::Definition->global_condition);
    $self->realm_config($realm, "workflow.global.field",
        OpenXPKI::Test::Role::WithWorkflows::Definition->global_field);
    $self->realm_config($realm, "workflow.global.validator",
        OpenXPKI::Test::Role::WithWorkflows::Definition->global_validator);
    $self->realm_config($realm, "workflow.def.certificate_signing_request_v2",
        OpenXPKI::Test::Role::WithWorkflows::Definition->def_certificate_signing_request_v2);
};

after 'init_server' => sub {
    my $self = shift;

    OpenXPKI::Server::Context::CTX('session')->data->pki_realm($self->config_writer->realms->[0]);
    OpenXPKI::Server::Context::CTX('session')->data->user('raop');
    OpenXPKI::Server::Context::CTX('session')->data->role('RA Operator');
};

=head1 METHODS

The following methods are added to L<OpenXPKI::Test> when this role is applied:

=cut

sub api_command {
    my ($self, $command, $params) = @_;

    my $result;
    lives_ok {
        $result = OpenXPKI::Server::Context::CTX('api')->$command($params);
        $self->_last_api_result($result);
    } "API command '$command'";

    return $result;
}

sub wf_activity {
    my ($self, $expected_state, $activity, $params) = @_;

    if ($expected_state) {
        is $self->_last_api_result->{WORKFLOW}->{STATE}, $expected_state, "state is '$expected_state'";
    }

    return $self->api_command(
        execute_workflow_activity => {
            ID => $self->_workflow_id,
            ACTIVITY => $activity,
            PARAMS => $params,
        }
    );
}

=head2 create_cert

Runs a L<subtest|Test::More/subtest> that creates a certificate via workflow
I<certificate_signing_request_v2> (which is part of this role) and returns a
I<HashRef> with some certificate info.

Returned I<HashRef>:

    {
        req_key    => ...,
        identifier => ...,
        profile    => ...,
    }

=cut
sub create_cert {
    my ($self, @args) = @_;

    my $params = OpenXPKI::Test::Role::WithWorkflows::CertParams->new(@args);

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
        plan tests => 20 + ($is_server_profile ? 2 : 0);
        #plan tests => 16 + ($self->notbefore ? 2 : 0);

        my $result;

        lives_ok {
            $result = $self->api_command(
                create_workflow_instance => {
                    WORKFLOW => "certificate_signing_request_v2",
                    PARAMS => {
                        cert_profile => $params->profile,
                        cert_subject_style => "00_basic_style",
                    },
                }
            );
        } "Create workflow instance";

        ok $result->{WORKFLOW}->{ID} or die explain $result;

        $self->_workflow_id($result->{WORKFLOW}->{ID});
        note "Created workflow #".$self->_workflow_id;

        $self->wf_activity(
            'SETUP_REQUEST_TYPE',
            csr_provide_server_key_params => {
                key_alg => "rsa",
                enc_alg => 'aes256',
                key_gen_params => $serializer->serialize( { KEY_LENGTH => 2048 } ),
                password_type => 'client',
                csr_type => 'pkcs10'
            },
        );

        $self->wf_activity(
            'ENTER_KEY_PASSWORD',
            csr_ask_client_password => { _password => "m4#bDf7m3abd" },
        );

        $self->wf_activity(
            'ENTER_SUBJECT',
            csr_edit_subject => {
                cert_subject_parts => $serializer->serialize( \%cert_subject_parts ),
            },
        );

        if ($is_server_profile) {
            $self->wf_activity(
                'ENTER_SAN',
                csr_edit_san => {
                    cert_san_parts => $serializer->serialize( { } ),
                },
            );
        }

        $self->wf_activity(
            'ENTER_CERT_INFO',
            'csr_edit_cert_info' => {
                cert_info => $serializer->serialize( {
                    requestor_gname => $params->requestor_gname,
                    requestor_name  => $params->requestor_name,
                    requestor_email => $params->requestor_email,
                } )
            },
        );

        is $self->_last_api_result->{WORKFLOW}->{STATE}, 'SUBJECT_COMPLETE', "state is 'SUBJECT_COMPLETE'";

        # Test FQDNs should not validate so we need a policy exception request
        # (on rare cases the responsible router might return a valid address, so we check)
        my $msg;
        lives_ok {
            $msg = $self->api_command(
                get_workflow_info => { ID => $self->_workflow_id }
            );
        };
        my $actions = $msg->{STATE}->{option};
        my $intermediate_state;
        if (grep { /^csr_enter_policy_violation_comment$/ } @$actions) {
            diag "Test FQDNs do not resolve - handling policy violation" if $ENV{TEST_VERBOSE};
            $self->wf_activity(
                undef,
                csr_enter_policy_violation_comment => { policy_comment => 'This is just a test' },
            );
            $intermediate_state = 'PENDING_POLICY_VIOLATION';
        }
        else {
            diag "For whatever reason test FQDNs do resolve - submitting request" if $ENV{TEST_VERBOSE};
            $self->wf_activity(
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

        $self->wf_activity(
            $intermediate_state,
            csr_approve_csr => {},
        );
        is $self->_last_api_result->{WORKFLOW}->{STATE}, 'SUCCESS';

        lives_ok {
            my $temp = $self->api_command(
                get_workflow_info => { ID => $self->_workflow_id }
            );
            $cert_info = {
                req_key    => $temp->{WORKFLOW}->{CONTEXT}->{csr_serial},
                identifier => $temp->{WORKFLOW}->{CONTEXT}->{cert_identifier},
                profile    => $temp->{WORKFLOW}->{CONTEXT}->{cert_profile},
            }
        }
    };

    return $cert_info;
}

1;
