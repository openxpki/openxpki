package OpenXPKI::Test::CertHelper::Workflow;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::CertHelper::Workflow - Test helper that creates certificates
using OpenXPKI workflows

=head1 DESCRIPTION

This class is not intended for direct use. Please use the class methods in
L<OpenXPKI::Test::CertHelper> instead.

=cut

# Core modules
use File::Basename;

# CPAN modules
use Test::More;

# Project modules
use OpenXPKI::Serialization::Simple;

################################################################################
# Constructor attributes
#

=head2 new

Constructor.

Named parameters:

=over

=item * B<tester> - Instance of L<OpenXPKI::Test::More> (required)

=item * B<hostname> - Hostname for certificate (I<Str>, required)

=item * B<application_name> - Application name (I<Str>, required for client profile)

=item * B<hostname2> - List of additional hostnames for the certificate (I<ArrayRef[Str]>, optional for server profile)

=item * B<profile> - Certificate profile (I<Str>, optional, default: I18N_OPENXPKI_PROFILE_TLS_SERVER)

=item * B<requestor_gname> - Surname of person requesting cert (I<Str>, optional)

=item * B<requestor_name> - Name of person requesting cert (I<Str>, optional)

=item * B<requestor_email> - Email of person requesting cert (I<Str>, optional)

=item * B<notbefore> - Sets the "valid from" date of the cert (I<Int>, optional)

=item * B<notafter> - Sets the "valid to" date of the cert (I<Int>, optional)

=back

=cut

has tester => (
    is => 'rw',
    isa => 'OpenXPKI::Test::More',
    required => 1,
);
has hostname => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);
has application_name => (
    is => 'rw',
    isa => 'Str',
    default => "Joust",
);
has hostname2 => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [] },
);
has profile => (
    is => 'rw',
    isa => 'Str',
    default => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
);
has requestor_gname => (
    is => 'rw',
    isa => 'Str',
    default => "Andreas",
);
has requestor_name => (
    is => 'rw',
    isa => 'Str',
    default => "Anders",
);
has requestor_email => (
    is => 'rw',
    isa => 'Str',
    default => "andreas.anders\@mycompany.local",
);
has notbefore => (
    is => 'rw',
    isa => 'Int',
);
has notafter => (
    is => 'rw',
    isa => 'Int',
);

################################################################################
# METHODS
#

=head1 Methods

=head2 create_cert

Runs a L<subtest|Test::More/subtest> that creates a certificate via workflow
I<certificate_signing_request_v2> and returns a HashRef with some certificate
info.

=cut
sub create_cert {
    my $self = shift;
    my $test = $self->tester;
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $is_server_profile = $self->profile eq "I18N_OPENXPKI_PROFILE_TLS_SERVER";
    my $is_client_profile = $self->profile eq "I18N_OPENXPKI_PROFILE_TLS_CLIENT";

    my %cert_subject_parts = (
        # IP addresses instead of host names will make DNS lookups fail quicker
        hostname => $self->hostname,
        $is_server_profile ? (
            hostname2 => $self->hostname2,
            port => 8080,
        ) : (),
        $is_client_profile ? (
            application_name => $self->application_name,
        ) : (),
    );

    subtest "Create certificate (hostname ".$self->hostname.")" => sub {
        plan tests => 14 + ($is_server_profile ? 2 : 0);
        #plan tests => 16 + ($self->notbefore ? 2 : 0);

        $test->create_ok('certificate_signing_request_v2', {
            cert_profile => $self->profile,
            cert_subject_style => "00_basic_style",
        }, 'Create workflow: certificate signing request (hostname: '.$cert_subject_parts{hostname}.')')
            or die(explain($test->get_msg));

        $test->state_is('SETUP_REQUEST_TYPE') or die(explain($test->get_msg));
        $test->execute_ok('csr_provide_server_key_params', {
            key_alg => "rsa",
            enc_alg => 'aes256',
            key_gen_params => $serializer->serialize( { KEY_LENGTH => 2048 } ),
            password_type => 'client',
            csr_type => 'pkcs10'
        }) or die(explain($test->get_msg));

        $test->state_is('ENTER_KEY_PASSWORD') or die(explain($test->get_msg));
        $test->execute_ok('csr_ask_client_password', {
            _password => "m4#bDf7m3abd",
        }) or die(explain($test->get_msg));

        $test->state_is('ENTER_SUBJECT') or die(explain($test->get_msg));
        $test->execute_ok('csr_edit_subject', {
            cert_subject_parts => $serializer->serialize( \%cert_subject_parts )
        }) or die(explain($test->get_msg));

        if ($is_server_profile) {
            $test->state_is('ENTER_SAN') or die(explain($test->get_msg));
            $test->execute_ok('csr_edit_san', {
                cert_san_parts => $serializer->serialize( { } )
            }) or die(explain($test->get_msg));
        }

        $test->state_is('ENTER_CERT_INFO') or die(explain($test->get_msg));
        $test->execute_ok('csr_edit_cert_info', {
            cert_info => $serializer->serialize( {
                requestor_gname => $self->requestor_gname,
                requestor_name  => $self->requestor_name,
                requestor_email => $self->requestor_email,
            } )
        }) or die(explain($test->get_msg));

        $test->state_is('SUBJECT_COMPLETE') or die(explain($test->get_msg));

        # Test FQDNs should not validate so we need a policy exception request
        # (on rare cases the responsible router might return a valid address, so we check)
        my $msg = $test->get_client->send_receive_command_msg('get_workflow_info', { ID => $test->get_wfid });
        my $actions = $msg->{PARAMS}->{STATE}->{option};
        my $intermediate_state;
        if (grep { /^csr_enter_policy_violation_comment$/ } @$actions) {
            diag "Test FQDNs do not resolve - handling policy violation" if $ENV{TEST_VERBOSE};
            $test->execute_ok( 'csr_enter_policy_violation_comment', { policy_comment => 'This is just a test' } )
                or die(explain($test->get_msg));
            $intermediate_state ='PENDING_POLICY_VIOLATION';
        }
        else {
            diag "For whatever reason test FQDNs do resolve - submitting request" if $ENV{TEST_VERBOSE};
            $test->execute_ok( 'csr_submit' ) or die(explain($test->get_msg));
            $intermediate_state ='PENDING';
        }
        $test->state_is($intermediate_state) or die(explain($test->get_msg));

#        if ($self->notbefore) {
#            $test->execute_ok('csr_edit_validity', {
#                notbefore => $self->notbefore,
#                notafter => $self->notafter,
#            });
#            $test->state_is( ??? );
#        }

        $test->execute_ok('csr_approve_csr') or die(explain($test->get_msg));
        $test->state_is('SUCCESS') or die(explain($test->get_msg));
    };

    return {
        req_key    => $test->param('csr_serial'),
        identifier => $test->param('cert_identifier'),
        profile    => $test->param('cert_profile'),
    };
}

__PACKAGE__->meta->make_immutable;
