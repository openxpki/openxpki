package TestCerts;
use Moose;
use utf8;

=head1 Name

TestCerts - Helper class for tests to quickly create certificates etc.

=cut

use Test::More;
use Test::Exception;
use OpenXPKI::Server::Database::Util;
use OpenXPKI::Serialization::Simple;

################################################################################
# Constructor attributes
#

################################################################################
# Other attributes
#

################################################################################
# METHODS
#

=head1 Methods

=head2 create_cert

Runs a L<subtest|Test::More/subtest> that creates a certificate via workflow
I<certificate_signing_request_v2> and returns the certificate identifier.

Named parameters:

=over

=item * B<tester> - Instance of L<OpenXPKI::Test::More> (required)

=item * B<hostname> - Hostname for certificate (I<Str>, required)

=item * B<hostname2> - List of additional hostnames for the certificate (I<ArrayRef[Str]>, optional)

=item * B<profile> - Certificate profile (I<Str>, optional, default: I18N_OPENXPKI_PROFILE_TLS_SERVER)

=item * B<requestor_gname> - Surname of person requesting cert (I<Str>, optional)

=item * B<requestor_name> - Name of person requesting cert (I<Str>, optional)

=item * B<requestor_email> - Email of person requesting cert (I<Str>, optional)

=back

=cut

sub create_cert {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::Server::Database::Util
        tester          => { isa => 'OpenXPKI::Test::More' },
        hostname        => { isa => 'Str' },
        hostname2       => { isa => 'ArrayRef[Str]', optional => 1, default => [] },
        profile         => { isa => 'Str', optional => 1, default => "I18N_OPENXPKI_PROFILE_TLS_SERVER" },
        requestor_gname => { isa => 'Str', optional => 1, default => "Andreas" },
        requestor_name  => { isa => 'Str', optional => 1, default => "Anders" },
        requestor_email => { isa => 'Str', optional => 1, default => "andreas.anders\@mycompany.local" },
    );
    my $test = $args{tester};

    my $serializer = OpenXPKI::Serialization::Simple->new();

    my %cert_subject_parts = (
        # IP addresses instead of host names will make DNS lookups fail quicker
        hostname => $args{hostname},
        hostname2 => $args{hostname2},
        port => 8080,
    );

    subtest "Create certificate (hostname $args{hostname}" => sub {
        plan tests => 16;

        $test->create_ok('certificate_signing_request_v2', {
            cert_profile => $args{profile},
            cert_subject_style => "00_basic_style",
        }, 'Create workflow: certificate signing request (hostname: '.$cert_subject_parts{hostname}.')')
         or die "Workflow Create failed: $@";

        $test->state_is('SETUP_REQUEST_TYPE');
        $test->execute_ok('csr_provide_server_key_params', {
            key_alg => "rsa",
            enc_alg => 'aes256',
            key_gen_params => $serializer->serialize( { KEY_LENGTH => 2048 } ),
            password_type => 'client',
            csr_type => 'pkcs10'
        });

        $test->state_is('ENTER_KEY_PASSWORD');
        $test->execute_ok('csr_ask_client_password', {
            _password => "m4#bDf7m3abd",
        });

        $test->state_is('ENTER_SUBJECT');
        $test->execute_ok('csr_edit_subject', {
            cert_subject_parts => $serializer->serialize( \%cert_subject_parts )
        });

        $test->state_is('ENTER_SAN');
        $test->execute_ok('csr_edit_san', {
            cert_san_parts => $serializer->serialize( { } )
        });

        $test->state_is('ENTER_CERT_INFO');
        $test->execute_ok('csr_edit_cert_info', {
            cert_info => $serializer->serialize( {
                requestor_gname => $args{requestor_gname},
                requestor_name  => $args{requestor_name},
                requestor_email => $args{requestor_email},
            } )
        });

        $test->state_is('SUBJECT_COMPLETE');

        # Test FQDNs should not validate so we need a policy exception request
        # (on rare cases the responsible router might return a valid address, so we check)
        my $msg = $test->get_client->send_receive_command_msg('get_workflow_info', { ID => $test->get_wfid });
        my $actions = $msg->{PARAMS}->{STATE}->{option};
        my $intermediate_state;
        if (grep { /^csr_enter_policy_violation_comment$/ } @$actions) {
            diag "Test FQDNs do not resolve - handling policy violation";
            $test->execute_ok( 'csr_enter_policy_violation_comment', { policy_comment => 'This is just a test' } );
            $intermediate_state ='PENDING_POLICY_VIOLATION';
        }
        else {
            diag "For whatever reason test FQDNs do resolve - submitting request";
            $test->execute_ok( 'csr_submit' );
            $intermediate_state ='PENDING';
        }
        $test->state_is($intermediate_state);

        $test->execute_ok('csr_approve_csr');
        $test->state_is('SUCCESS');
    };

    return $test->param('cert_identifier');
}

__PACKAGE__->meta->make_immutable;
