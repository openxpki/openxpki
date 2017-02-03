package OpenXPKI::Test::CertHelper;
use Moose;
use utf8;

=head1 Name

OpenXPKI::Test::CertHelper - Helper class for tests to quickly create certificates etc.

=cut

# Core modules
use File::Basename;

# CPAN modules
use Test::More;

# Project modules
use OpenXPKI::MooseParams;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Test::PEM;

################################################################################
# Constructor attributes
#
has tester => (
    is => 'rw',
    isa => 'OpenXPKI::Test::More',
    required => 1,
);

################################################################################
# Other attributes
#
has certs => (
    is => 'rw',
    isa => 'HashRef[OpenXPKI::Test::PEM]',
    lazy => 1,
    builder => '_build_certs',
);

################################################################################
# METHODS
#

=head1 Methods

=head2 all_cert_ids

Returns an ArrayRef with the IDs ("subject_key_identifier") of all test
certificates handled by this class.

=cut
sub all_cert_ids {
    my $self = shift;
    return [ map { $_->id } values %{$self->certs} ];
}

=head2 all_cert_names

Returns an ArrayRef with the internal short names of all test certificates
handled by this class.

=cut
sub all_cert_names {
    my $self = shift;
    return [ keys %{$self->certs} ];
}


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
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParam
        hostname        => { isa => 'Str' },
        hostname2       => { isa => 'ArrayRef[Str]', optional => 1, default => [] },
        profile         => { isa => 'Str', optional => 1, default => "I18N_OPENXPKI_PROFILE_TLS_SERVER" },
        requestor_gname => { isa => 'Str', optional => 1, default => "Andreas" },
        requestor_name  => { isa => 'Str', optional => 1, default => "Anders" },
        requestor_email => { isa => 'Str', optional => 1, default => "andreas.anders\@mycompany.local" },
    );
    my $test = $self->tester;
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my %cert_subject_parts = (
        # IP addresses instead of host names will make DNS lookups fail quicker
        hostname => $args{hostname},
        hostname2 => $args{hostname2},
        port => 8080,
    );

    subtest "Create certificate (hostname $args{hostname})" => sub {
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

# Test certificate data
sub _build_certs {
    return {
        acme_root => OpenXPKI::Test::PEM->new(
            label => "ACME Root CA",
            database => {
                authority_key_identifier => '39:D5:86:02:69:BC:E1:3D:7A:25:88:A9:B9:CD:F5:EB:DE:6F:91:7B',
                cert_key => '13135268448054154766',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkzCCAnugAwIBAgIJALZJ2Q9TqhYOMA0GCSqGSIb3DQEBCwUAMFgxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTEQMA4GA1UE\nCwwHQUNNRSBDQTEVMBMGA1UEAwwMQUNNRSBSb290IENBMB4XDTE3MDEyNjIzNTc0\nNloXDTE3MDIyNTIzNTc0NlowWDETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmS\nJomT8ixkARkWCE9wZW5YUEtJMRAwDgYDVQQLDAdBQ01FIENBMRUwEwYDVQQDDAxB\nQ01FIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDGqucT\nt0rtvm9hiIcjGa1WLQSRQm4eL07DAFgOeYXgWKD/qYi7i+aJ4SkxNf5oUUYr0URm\nfmchsP7rZLrgqPtRSFscwNlalk7p0oUYzk+iJQ94elV6pSJNe9aBrd5BbnC6Di40\nnbrutwzrA/rjx57liSBSYh0oyRKZyQaDAwasiPlTGES8fNFJhABT6voaP5Cg+Vxs\n2Mtct5aGrxvyCsueaUlWjOn8p0x3VKDJc9apAb2ehQleyTObsToAmG/rbT+gQaxs\nYZLKYPvuRhj6D02NLyV36wAuOE4MisrMkMDbzC9xxVRnL0uAAe4YbEK8HfyQRmNC\npaBBVGdqHcr2SxazAgMBAAGjYDBeMB0GA1UdDgQWBBQ51YYCabzhPXoliKm5zfXr\n3m+RezAfBgNVHSMEGDAWgBQ51YYCabzhPXoliKm5zfXr3m+RezAPBgNVHRMBAf8E\nBTADAQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAGqLCraMmbI8C\nIO1YbYd/5E3T7N5vjYzYBhWprXYnbHFOCdGewKfeBYZkAwKhuFdncyduWzd0MMoV\nANe+XIqaghvX7Vay53GDB3NbyZczQexwiKLBLGiRwp/Rc/tK9IxYLXH8B/L+p2z2\nyI6IIfmN6MS97WRqvp9XVt0A5/hZTuYHi3bejdhCW+9q8buCOKx5LPzBCenBW7sz\nzs2VGe1g9NySboj2/IlhSki2wJKcTySh1sJwd8pr1I+RGsR8nK1BiRmL8urVHy+g\ng9Dh+Tv8f1XMkuZ7MGtwc9Lxceyk+7lKbF1w38mg0FadAvPh8gxuZmh0whUS8/Fx\nwQt28SCAiA==\n-----END CERTIFICATE-----\n",
                identifier => 'XpT4kjJYefgdswyPFteaw80ha54',
                issuer_dn => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'XpT4kjJYefgdswyPFteaw80ha54',
                loa => undef,
                notafter => '1488067066',
                notbefore => '1485475066',
                pki_realm => 'acme',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c6:aa:e7:13:b7:4a:ed:be:6f:61:88:87:23:19:\n    ad:56:2d:04:91:42:6e:1e:2f:4e:c3:00:58:0e:79:\n    85:e0:58:a0:ff:a9:88:bb:8b:e6:89:e1:29:31:35:\n    fe:68:51:46:2b:d1:44:66:7e:67:21:b0:fe:eb:64:\n    ba:e0:a8:fb:51:48:5b:1c:c0:d9:5a:96:4e:e9:d2:\n    85:18:ce:4f:a2:25:0f:78:7a:55:7a:a5:22:4d:7b:\n    d6:81:ad:de:41:6e:70:ba:0e:2e:34:9d:ba:ee:b7:\n    0c:eb:03:fa:e3:c7:9e:e5:89:20:52:62:1d:28:c9:\n    12:99:c9:06:83:03:06:ac:88:f9:53:18:44:bc:7c:\n    d1:49:84:00:53:ea:fa:1a:3f:90:a0:f9:5c:6c:d8:\n    cb:5c:b7:96:86:af:1b:f2:0a:cb:9e:69:49:56:8c:\n    e9:fc:a7:4c:77:54:a0:c9:73:d6:a9:01:bd:9e:85:\n    09:5e:c9:33:9b:b1:3a:00:98:6f:eb:6d:3f:a0:41:\n    ac:6c:61:92:ca:60:fb:ee:46:18:fa:0f:4d:8d:2f:\n    25:77:eb:00:2e:38:4e:0c:8a:ca:cc:90:c0:db:cc:\n    2f:71:c5:54:67:2f:4b:80:01:ee:18:6c:42:bc:1d:\n    fc:90:46:63:42:a5:a0:41:54:67:6a:1d:ca:f6:4b:\n    16:b3\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '39:D5:86:02:69:BC:E1:3D:7A:25:88:A9:B9:CD:F5:EB:DE:6F:91:7B',
            },
        ),
        acme_signer => OpenXPKI::Test::PEM->new(
            label => "ACME Signing CA",
            database => {
                authority_key_identifier => '39:D5:86:02:69:BC:E1:3D:7A:25:88:A9:B9:CD:F5:EB:DE:6F:91:7B',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkDCCAnigAwIBAgIBATANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxEDAOBgNVBAsMB0FDTUUg\nQ0ExFTATBgNVBAMMDEFDTUUgUm9vdCBDQTAgFw0xNzAxMjYyMzU3NDZaGA8yMTE3\nMDEwMjIzNTc0NlowWzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMRAwDgYDVQQLDAdBQ01FIENBMRgwFgYDVQQDDA9BQ01FIFNp\nZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDZi/JMSisK\n32KsaAtORfTmiQo61hrPwMJz04NeWZ2wls+EUBpdOMkw6MwKW3l374zGYw3E7X60\nRhs5OgBFifKmn6IvYSMAy4UWRuMRZfz8sBh1zIoRQ3B35WBYwoj/YQ8Ia4bV+NW/\nVf+cyAL8+5fPLSUvQw2ZnMc5i29CLgYAJeCGK+iIbAlVo/CwRVhGweCsKLFAKZdz\naat4LcOvWjE4PVNHPV170Too5AYZBB6Tv9ET3SeRA412ywrCc+XIEql+XPC9I7Ft\nSPQcq/TCNJwVOU+NL49pbRWk9XavvLeFfRIAtdRacF1CKBymW9kCtBZdG3d6MDWK\nx4VsGxMjpMF3AgMBAAGjYDBeMB0GA1UdDgQWBBTaG83SAKlxggXnefyjrRBdjzkb\nrDAfBgNVHSMEGDAWgBQ51YYCabzhPXoliKm5zfXr3m+RezAPBgNVHRMBAf8EBTAD\nAQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAJ0ixQPjykwHazFkA\nJzEwm1b+rE2lq85uyjmGFDY4FZR4c/L/w5setGYG1990/5sQPJvriiZ5fiJ6HGJ9\n0DaqizBgBuwCVkKDghCXvEZnOJKPOqw6rxUj+0+0Y3AgnzTV+fWArFv4HVCg3rIB\n9I00JOHlZLdDhuyU5WbcVyhEc2mkeKbK5u+zHhF48l8+2lcUd/Qiqiy9pM0NCXz4\nAPNZ7suXlS8im3YgfDyt/FYFIN4nqE3OEWjqYzObiQMyobSg1JwYCGVmiSl/nSsw\nzjulyhprxW47AfQzf3fNBR7gZBv/QFYtXJBpzOYDyc58+d3TEmM9tjpzlNN5KSfD\nuZ8RLw==\n-----END CERTIFICATE-----\n",
                identifier => 'P5nU2HjbKzKfpJV7P30FrNtXdVA',
                issuer_dn => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'XpT4kjJYefgdswyPFteaw80ha54',
                loa => undef,
                notafter => '4294967295',
                notbefore => '1485475066',
                pki_realm => 'acme',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d9:8b:f2:4c:4a:2b:0a:df:62:ac:68:0b:4e:45:\n    f4:e6:89:0a:3a:d6:1a:cf:c0:c2:73:d3:83:5e:59:\n    9d:b0:96:cf:84:50:1a:5d:38:c9:30:e8:cc:0a:5b:\n    79:77:ef:8c:c6:63:0d:c4:ed:7e:b4:46:1b:39:3a:\n    00:45:89:f2:a6:9f:a2:2f:61:23:00:cb:85:16:46:\n    e3:11:65:fc:fc:b0:18:75:cc:8a:11:43:70:77:e5:\n    60:58:c2:88:ff:61:0f:08:6b:86:d5:f8:d5:bf:55:\n    ff:9c:c8:02:fc:fb:97:cf:2d:25:2f:43:0d:99:9c:\n    c7:39:8b:6f:42:2e:06:00:25:e0:86:2b:e8:88:6c:\n    09:55:a3:f0:b0:45:58:46:c1:e0:ac:28:b1:40:29:\n    97:73:69:ab:78:2d:c3:af:5a:31:38:3d:53:47:3d:\n    5d:7b:d1:3a:28:e4:06:19:04:1e:93:bf:d1:13:dd:\n    27:91:03:8d:76:cb:0a:c2:73:e5:c8:12:a9:7e:5c:\n    f0:bd:23:b1:6d:48:f4:1c:ab:f4:c2:34:9c:15:39:\n    4f:8d:2f:8f:69:6d:15:a4:f5:76:af:bc:b7:85:7d:\n    12:00:b5:d4:5a:70:5d:42:28:1c:a6:5b:d9:02:b4:\n    16:5d:1b:77:7a:30:35:8a:c7:85:6c:1b:13:23:a4:\n    c1:77\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME Signing CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'DA:1B:CD:D2:00:A9:71:82:05:E7:79:FC:A3:AD:10:5D:8F:39:1B:AC',
            },
        ),
        acme2_root => OpenXPKI::Test::PEM->new(
            label => "ACME-2 Root CA",
            database => {
                authority_key_identifier => 'C6:17:6E:AC:2E:7F:3C:9B:B0:AB:83:B6:5A:C2:F0:14:6C:A9:A4:4A',
                cert_key => '15209797771827521724',
                data => "-----BEGIN CERTIFICATE-----\nMIIDhzCCAm+gAwIBAgIJANMUDn0PTqi8MA0GCSqGSIb3DQEBCwUAMFIxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UE\nCwwEQUNNRTESMBAGA1UEAwwJUm9vdCBDQSAyMB4XDTE3MDIwMTIzMzA0M1oXDTE3\nMDMwMzIzMzA0M1owUjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRIwEAYDVQQDDAlSb290IENBIDIw\nggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDeE4yDkkcpCf6y6ZxlnsDT\nsdrD4rE6Uzrt7TEbkAMFj62Rwgtj6BFskJ1+fOwNWDi34smX8meC6NVQCQNi7BeP\nBxscO9qVGq/JG9TA0nvTWXPq7lYjkKeq9/5f1s2rxGJMzntHePJvVoVxFIMyRmmJ\n7SJDSLCbEtGkhwnWvTGZ8MF3xaNQOKLlUAZCbXvS3+tjlofAHffKxJ7GX50GzAcv\nVTchxQyUIDmhaYsD/9XRz225cQQBq95+xkkZvBNOi1XjbQg12nwdtWmCA0T9NbPl\nQgMYVUqaW7RF2HSWB2JaK7BbiMAb0xsj8IPlNzHWV7B7mTEylWOTCYpHYWTlbnQF\nAgMBAAGjYDBeMB0GA1UdDgQWBBTGF26sLn88m7Crg7ZawvAUbKmkSjAfBgNVHSME\nGDAWgBTGF26sLn88m7Crg7ZawvAUbKmkSjAPBgNVHRMBAf8EBTADAQH/MAsGA1Ud\nDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAu3LEO5y0XEzSsolsktz99mSQCw+p\niqgQKNOFVnOdgQmGMFb12vw2maGtAJKI1xIA5/LOkM8Po7whuaKh3LLQVlQczI/e\ng1avhMFjc8K/QAkU2p4doIl1hnWqOfyyZ31kKaTg3qomul2uf5k5PEL2SaOzGlLP\nkX1u3hkC8JwfRJ+WohuY9J2QD6m1jbDdFyMXVVsc9CfO0TTaru3us5af/lHvYJ7k\n/Qi+ft99Aajh0wWMWfUOqm10+6/413ZCGh2QSmDHBnRTwwv++ONEyshBwvgTQCdV\nf2YyLv7wkP/2R4dywmJ9tv951ZrtpW1Hi9lAg3pqVd/VFdTLMFu1doy+7Q==\n-----END CERTIFICATE-----\n",
                identifier => 'pyuKYLHcfBMkXdeP9u0iudgFvnA',
                issuer_dn => 'CN=Root CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'pyuKYLHcfBMkXdeP9u0iudgFvnA',
                loa => undef,
                notafter => '1488583843',
                notbefore => '1485991843',
                pki_realm => 'acme-2',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:de:13:8c:83:92:47:29:09:fe:b2:e9:9c:65:9e:\n    c0:d3:b1:da:c3:e2:b1:3a:53:3a:ed:ed:31:1b:90:\n    03:05:8f:ad:91:c2:0b:63:e8:11:6c:90:9d:7e:7c:\n    ec:0d:58:38:b7:e2:c9:97:f2:67:82:e8:d5:50:09:\n    03:62:ec:17:8f:07:1b:1c:3b:da:95:1a:af:c9:1b:\n    d4:c0:d2:7b:d3:59:73:ea:ee:56:23:90:a7:aa:f7:\n    fe:5f:d6:cd:ab:c4:62:4c:ce:7b:47:78:f2:6f:56:\n    85:71:14:83:32:46:69:89:ed:22:43:48:b0:9b:12:\n    d1:a4:87:09:d6:bd:31:99:f0:c1:77:c5:a3:50:38:\n    a2:e5:50:06:42:6d:7b:d2:df:eb:63:96:87:c0:1d:\n    f7:ca:c4:9e:c6:5f:9d:06:cc:07:2f:55:37:21:c5:\n    0c:94:20:39:a1:69:8b:03:ff:d5:d1:cf:6d:b9:71:\n    04:01:ab:de:7e:c6:49:19:bc:13:4e:8b:55:e3:6d:\n    08:35:da:7c:1d:b5:69:82:03:44:fd:35:b3:e5:42:\n    03:18:55:4a:9a:5b:b4:45:d8:74:96:07:62:5a:2b:\n    b0:5b:88:c0:1b:d3:1b:23:f0:83:e5:37:31:d6:57:\n    b0:7b:99:31:32:95:63:93:09:8a:47:61:64:e5:6e:\n    74:05\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=Root CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'C6:17:6E:AC:2E:7F:3C:9B:B0:AB:83:B6:5A:C2:F0:14:6C:A9:A4:4A',
            },
        ),
        acme2_signer => OpenXPKI::Test::PEM->new(
            label => "ACME-2 Signing CA",
            database => {
                authority_key_identifier => 'C6:17:6E:AC:2E:7F:3C:9B:B0:AB:83:B6:5A:C2:F0:14:6C:A9:A4:4A',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDhDCCAmygAwIBAgIBATANBgkqhkiG9w0BAQsFADBSMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nEjAQBgNVBAMMCVJvb3QgQ0EgMjAgFw0xNzAyMDEyMzMwNDNaGA8yMTE3MDEwODIz\nMzA0M1owVTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixkARkWCE9w\nZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRUwEwYDVQQDDAxTaWduaW5nIENBIDIwggEi\nMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDBn1ojQnzB/hLbdwnxhp/MHuEc\nd+9MhjjeaGNCoCBH6UvySm9SBD0dJ5OaPSveNvsdBtlFggEiQ7zT44ne7ndYJkHv\ny8xTSTKim/hQT10brdQqEte27+9GZUJAYeYVzwEn5b0v/jKAy8AxQiUXgRd03mED\nbAQ2rGwAjZhu5kFjiy+/8fj1lgOp2z3uwKu1j5gyIu8MLIwFDRu05ip37REEE3rS\nrCYO0IUhZxe6WfInixBlp5WmwZ3zJr3SiW8rJAnNj6EYfrqzjlyJ1QDM/+zpdTWV\nqKSzdtEs3UI21nYTvuUK3LUisvq5+kqY3juJF8JnXPKRNaO0do2RmUN1ZRwjAgMB\nAAGjYDBeMB0GA1UdDgQWBBQaYBjlEC7Z+9KlfHYM6lr3NnEFuzAfBgNVHSMEGDAW\ngBTGF26sLn88m7Crg7ZawvAUbKmkSjAPBgNVHRMBAf8EBTADAQH/MAsGA1UdDwQE\nAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAB4SDMiQubFQx2Ttqsz9yatoXC4nxIpgA\nJrNcNJY6d43WSeRVGSskNUR28s0wkttreB9899dXyP7GbkqisYaQRuEINjn5hu7V\n3MO2ggKhNwH2VPXGWGy85ogd4l8NglghOWhD+ERPYFHFEJ+e8llNJyNnHiEa9gWv\n4VDq9IOx6DLI4fkc1ZcnlJvnnwbGk4lYtSmfKFvL4RGxC70idrZNdqsrTrNS0gCk\ndoo5PzE48QzgoNOkSDdim2gagBhMKmyEgdIRtGwUCUZHMOTR5grJNmIy2HSSjcko\n/9Xc6TlmL/AOoFZlUM4zOdhlX8E9kibglah5qRolLtvKxkIMo/9YPA==\n-----END CERTIFICATE-----\n",
                identifier => 'RM_-RMqaEL1-rdvqvHjvJe16vlo',
                issuer_dn => 'CN=Root CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'pyuKYLHcfBMkXdeP9u0iudgFvnA',
                loa => undef,
                notafter => '4294967295',
                notbefore => '1485991843',
                pki_realm => 'acme-2',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c1:9f:5a:23:42:7c:c1:fe:12:db:77:09:f1:86:\n    9f:cc:1e:e1:1c:77:ef:4c:86:38:de:68:63:42:a0:\n    20:47:e9:4b:f2:4a:6f:52:04:3d:1d:27:93:9a:3d:\n    2b:de:36:fb:1d:06:d9:45:82:01:22:43:bc:d3:e3:\n    89:de:ee:77:58:26:41:ef:cb:cc:53:49:32:a2:9b:\n    f8:50:4f:5d:1b:ad:d4:2a:12:d7:b6:ef:ef:46:65:\n    42:40:61:e6:15:cf:01:27:e5:bd:2f:fe:32:80:cb:\n    c0:31:42:25:17:81:17:74:de:61:03:6c:04:36:ac:\n    6c:00:8d:98:6e:e6:41:63:8b:2f:bf:f1:f8:f5:96:\n    03:a9:db:3d:ee:c0:ab:b5:8f:98:32:22:ef:0c:2c:\n    8c:05:0d:1b:b4:e6:2a:77:ed:11:04:13:7a:d2:ac:\n    26:0e:d0:85:21:67:17:ba:59:f2:27:8b:10:65:a7:\n    95:a6:c1:9d:f3:26:bd:d2:89:6f:2b:24:09:cd:8f:\n    a1:18:7e:ba:b3:8e:5c:89:d5:00:cc:ff:ec:e9:75:\n    35:95:a8:a4:b3:76:d1:2c:dd:42:36:d6:76:13:be:\n    e5:0a:dc:b5:22:b2:fa:b9:fa:4a:98:de:3b:89:17:\n    c2:67:5c:f2:91:35:a3:b4:76:8d:91:99:43:75:65:\n    1c:23\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=Signing CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '1A:60:18:E5:10:2E:D9:FB:D2:A5:7C:76:0C:EA:5A:F7:36:71:05:BB',
            },
        ),
        acme2_client => OpenXPKI::Test::PEM->new(
            label => "ACME-2 Client",
            database => {
                authority_key_identifier => '1A:60:18:E5:10:2E:D9:FB:D2:A5:7C:76:0C:EA:5A:F7:36:71:05:BB',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDcDCCAligAwIBAgIBAjANBgkqhkiG9w0BAQsFADBVMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFTATBgNVBAMMDFNpZ25pbmcgQ0EgMjAgFw0xNzAyMDEyMzMwNDRaGA8yMTE3MDEw\nODIzMzA0NFowUTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixkARkW\nCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMREwDwYDVQQDDAhDbGllbnQgMjCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPOWNuE7+dUxnG+BE1Vcj/Tucj+R\nwFAEidcRNFR4wzN+Uo9daewy/tSGbiOaIBPjgW13jN2YX9zU8aMJtWqONsN2VT5s\nat103V/jY5ifMaFszjNl7Da6r6F/eruGS3U4Gmq2Mk+pVzTddEe6MlwcTQvxvpJ2\n1mKVQ4eiOYwCKHagNyP4yOlsuFYyHufzFTqe6JC1fcUM48quFsWvDf7W9IP8S8OS\nqe7pblmKZFkyzGq6zr+U7MAjNCWc2Eg7/jfiiccHw7y1gAv66HdfiMG9Xc3WA1pw\nJIxxkAPvpBIL7E2aDw5VrtDSrxMfS7PSqGmuDh4Bqkv72ZGqLekWoQbPkpUCAwEA\nAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUut0HQHF8IEAxB+7p9itapcKTxVkw\nHwYDVR0jBBgwFoAUGmAY5RAu2fvSpXx2DOpa9zZxBbswDQYJKoZIhvcNAQELBQAD\nggEBAGagGX+wq+SYyc8t4ptsP8zQFkSAjiC+uL8jVfC1QrbMUY4WcqjJT6WcA4V7\n8D5g0Hv282haPc/a3ixbktMKv5jdIkTnYCHp/3WOsjk8PpVURMSfkHxDl1uZ/Z1R\njpfG/4RuRFtdGHVTlVdQKbLIFw0njIcm0TH+ajBBr2pfNyen0XZvl4eT6UFb4FhF\nyesk+Rtsf2hkSkehtrkHa4TdfFUkAQp7GXIVY2pjwcI7qnsahuwtc+xHxfujknA4\nZtlqInl8rZj2LExtY8NDkWNF6oNBPr8hA+1KSJE08zjabO87GtbGb80qasnOX1B2\ntbDZc71YbzIOkWmt6vbpF+g0fUo=\n-----END CERTIFICATE-----\n",
                identifier => 'bFWte6KSMTaQIYHx2SHXFPVBiIo',
                issuer_dn => 'CN=Signing CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'RM_-RMqaEL1-rdvqvHjvJe16vlo',
                loa => undef,
                notafter => '4294967295',
                notbefore => '1485991844',
                pki_realm => 'acme-2',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:f3:96:36:e1:3b:f9:d5:31:9c:6f:81:13:55:5c:\n    8f:f4:ee:72:3f:91:c0:50:04:89:d7:11:34:54:78:\n    c3:33:7e:52:8f:5d:69:ec:32:fe:d4:86:6e:23:9a:\n    20:13:e3:81:6d:77:8c:dd:98:5f:dc:d4:f1:a3:09:\n    b5:6a:8e:36:c3:76:55:3e:6c:6a:dd:74:dd:5f:e3:\n    63:98:9f:31:a1:6c:ce:33:65:ec:36:ba:af:a1:7f:\n    7a:bb:86:4b:75:38:1a:6a:b6:32:4f:a9:57:34:dd:\n    74:47:ba:32:5c:1c:4d:0b:f1:be:92:76:d6:62:95:\n    43:87:a2:39:8c:02:28:76:a0:37:23:f8:c8:e9:6c:\n    b8:56:32:1e:e7:f3:15:3a:9e:e8:90:b5:7d:c5:0c:\n    e3:ca:ae:16:c5:af:0d:fe:d6:f4:83:fc:4b:c3:92:\n    a9:ee:e9:6e:59:8a:64:59:32:cc:6a:ba:ce:bf:94:\n    ec:c0:23:34:25:9c:d8:48:3b:fe:37:e2:89:c7:07:\n    c3:bc:b5:80:0b:fa:e8:77:5f:88:c1:bd:5d:cd:d6:\n    03:5a:70:24:8c:71:90:03:ef:a4:12:0b:ec:4d:9a:\n    0f:0e:55:ae:d0:d2:af:13:1f:4b:b3:d2:a8:69:ae:\n    0e:1e:01:aa:4b:fb:d9:91:aa:2d:e9:16:a1:06:cf:\n    92:95\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=Client 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'BA:DD:07:40:71:7C:20:40:31:07:EE:E9:F6:2B:5A:A5:C2:93:C5:59',
            },
        ),
        expired_root => OpenXPKI::Test::PEM->new(
            label => "Expired Root CA",
            database => {
                authority_key_identifier => '94:3A:81:EF:5C:58:88:A8:97:CD:34:FF:35:DD:EB:71:B6:FE:FA:2E',
                cert_key => '11692266029049298850',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkzCCAnugAwIBAgIJAKJDRgFQ2b+iMA0GCSqGSIb3DQEBCwUAMFgxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTEQMA4GA1UE\nCwwHQUNNRSBDQTEVMBMGA1UEAwwMQUNNRSBSb290IENBMB4XDTE1MDEyNzAwMTUw\nMVoXDTE1MDIyNjAwMTUwMVowWDETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmS\nJomT8ixkARkWCE9wZW5YUEtJMRAwDgYDVQQLDAdBQ01FIENBMRUwEwYDVQQDDAxB\nQ01FIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDnHV0W\nZnsX4LBZNI9iMoidOhBx/fOTRCHjO/73ms16begvDSqbhwDZms5OhC9BYAmmmYjJ\nIvlPkOR/IiU6bLtgDk9WZjIbKw28gjM4C6EZtCPa2vxwXJUR5vcDZerdN3/9IAAm\n0vMHgFzDxC0t472yURF9B4oRXbN2RxQ197SMml+2XlnWc6bBSNSVWfCWVHbTlU00\nW4nWqIoPcGk2MceMgo9t4Ta/jpfXivMWRJ3SGw+HH6ETtJmI8BpQNzarawsOEKKN\n1zCy5Wya4U72KwitZpr1Qcr1d+kLe5NLGPVrQpYBHjmxXWXza7VxVEW79TKtzu2g\n8jRMpkYKfd0TlcY3AgMBAAGjYDBeMB0GA1UdDgQWBBSUOoHvXFiIqJfNNP813etx\ntv76LjAfBgNVHSMEGDAWgBSUOoHvXFiIqJfNNP813etxtv76LjAPBgNVHRMBAf8E\nBTADAQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEABLiqD5BzqFCK\nB7aqWZs29Xc42DlofJN3i0NXTWcM0bNuQJqOJMR96seyNPZZu41pHnJV0WDPhuNL\nD0tXku1TSGpf6fmmuPSfxksXjNG9HXivmPA89u6DfPA4+BZ+Q+yOIKQeciHkODUQ\n+g8kWASmMH4zWXxQpZQ9iI7LdZxRRmuwpCATuyth/yU6aa6aJsg4Juuf4P5OO4vs\nvC1kqgUWNc/OIHzgu6NBLv2XUr0mka3iRT4hsZcFBgyKJhf4b1hmC24WakuWqSaS\n/hx42PNwpbirUlNVrHWIm50z3jRCKgJHfJwrpWIWxMkEz6Rn9AeY2AEUpy5RGjPU\nfvP239/QKg==\n-----END CERTIFICATE-----\n",
                identifier => 'ig29xFOKRNUpPh8spF6hyCWgExA',
                issuer_dn => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'ig29xFOKRNUpPh8spF6hyCWgExA',
                loa => undef,
                notafter => '1424909701',
                notbefore => '1422317701',
                pki_realm => undef,
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:e7:1d:5d:16:66:7b:17:e0:b0:59:34:8f:62:32:\n    88:9d:3a:10:71:fd:f3:93:44:21:e3:3b:fe:f7:9a:\n    cd:7a:6d:e8:2f:0d:2a:9b:87:00:d9:9a:ce:4e:84:\n    2f:41:60:09:a6:99:88:c9:22:f9:4f:90:e4:7f:22:\n    25:3a:6c:bb:60:0e:4f:56:66:32:1b:2b:0d:bc:82:\n    33:38:0b:a1:19:b4:23:da:da:fc:70:5c:95:11:e6:\n    f7:03:65:ea:dd:37:7f:fd:20:00:26:d2:f3:07:80:\n    5c:c3:c4:2d:2d:e3:bd:b2:51:11:7d:07:8a:11:5d:\n    b3:76:47:14:35:f7:b4:8c:9a:5f:b6:5e:59:d6:73:\n    a6:c1:48:d4:95:59:f0:96:54:76:d3:95:4d:34:5b:\n    89:d6:a8:8a:0f:70:69:36:31:c7:8c:82:8f:6d:e1:\n    36:bf:8e:97:d7:8a:f3:16:44:9d:d2:1b:0f:87:1f:\n    a1:13:b4:99:88:f0:1a:50:37:36:ab:6b:0b:0e:10:\n    a2:8d:d7:30:b2:e5:6c:9a:e1:4e:f6:2b:08:ad:66:\n    9a:f5:41:ca:f5:77:e9:0b:7b:93:4b:18:f5:6b:42:\n    96:01:1e:39:b1:5d:65:f3:6b:b5:71:54:45:bb:f5:\n    32:ad:ce:ed:a0:f2:34:4c:a6:46:0a:7d:dd:13:95:\n    c6:37\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '94:3A:81:EF:5C:58:88:A8:97:CD:34:FF:35:DD:EB:71:B6:FE:FA:2E',
            },
        ),
        expired_signer => OpenXPKI::Test::PEM->new(
            label => "Cert signed by expired Root CA",
            database => {
                authority_key_identifier => '94:3A:81:EF:5C:58:88:A8:97:CD:34:FF:35:DD:EB:71:B6:FE:FA:2E',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBATANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxEDAOBgNVBAsMB0FDTUUg\nQ0ExFTATBgNVBAMMDEFDTUUgUm9vdCBDQTAeFw0xNTAxMjcwMDE1MDJaFw0xNTAx\nMjgwMDE1MDJaMFsxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZ\nFghPcGVuWFBLSTEQMA4GA1UECwwHQUNNRSBDQTEYMBYGA1UEAwwPQUNNRSBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxwgkacEdUlZs\nxzJQqz58AJgu6ikPIb3zWbr/BaG+usjmVC+WabqmUiPHllbE7/TfBn4T4uxtXPBa\nxmIVueoXbGhexgTorGPAReQqhUPZ5KlEGVqb02hc0uIJ1ff8eiRlitqeO0GbCIzo\nJXsYw323m3YYftxlbFIt26gFikvi9zaoeaoxDFyky+fErBkvle6JGV508aZBph/S\nBr3xmzylrVEoO4bkePDIaQBzdUNRh6FDG7ING+YbjtZfYgS2UjP3gg474EeztbtH\ngPww2aUfnlIYtXqqt9bXSrbywJ4EM/OvSr26S1Txuh8tp5fC9tngTmb1ypnlUnOt\nnlA1JK/9oQIDAQABo2AwXjAdBgNVHQ4EFgQU5zb2OrQeUD6wx6nX1ZriqoCmD7ww\nHwYDVR0jBBgwFoAUlDqB71xYiKiXzTT/Nd3rcbb++i4wDwYDVR0TAQH/BAUwAwEB\n/zALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBANQpf3CrUNOc2XD5cvJV\nIbS4zE1pxRq/bsxkK3nj9th9OdseAqsiWwKuLz1j8KkFN+2eqjvisH5UCzcW/n4k\nJFjFJ+hq0UKkqiGv6KtdMIhdM8rODDnwLQGMCD8vKqNZk3vI1lFbEuTmlz9a95d8\nVkWfgz4/8a7PmIcMp87jFiepweobeHoq+081sHwQnUMgjLujLscfJevHWSrbtFD9\nOPWyyp62FbHQckU5tn6dQYgJsLCJp7jJ8jf5RCQaXKwV+Q0qhDOyaCVIhCzP5gW2\n+BylcwN+rNmBH0RP0QzurBU0PrR2xrlAzXZYuMAB8D0cAsziyvPZtV5fDn9RZG7G\nvW0=\n-----END CERTIFICATE-----\n",
                identifier => 'fcE0MpW-8xXvb5gZTiVYkNMHP30',
                issuer_dn => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'ig29xFOKRNUpPh8spF6hyCWgExA',
                loa => undef,
                notafter => '1422404102',
                notbefore => '1422317702',
                pki_realm => undef,
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c7:08:24:69:c1:1d:52:56:6c:c7:32:50:ab:3e:\n    7c:00:98:2e:ea:29:0f:21:bd:f3:59:ba:ff:05:a1:\n    be:ba:c8:e6:54:2f:96:69:ba:a6:52:23:c7:96:56:\n    c4:ef:f4:df:06:7e:13:e2:ec:6d:5c:f0:5a:c6:62:\n    15:b9:ea:17:6c:68:5e:c6:04:e8:ac:63:c0:45:e4:\n    2a:85:43:d9:e4:a9:44:19:5a:9b:d3:68:5c:d2:e2:\n    09:d5:f7:fc:7a:24:65:8a:da:9e:3b:41:9b:08:8c:\n    e8:25:7b:18:c3:7d:b7:9b:76:18:7e:dc:65:6c:52:\n    2d:db:a8:05:8a:4b:e2:f7:36:a8:79:aa:31:0c:5c:\n    a4:cb:e7:c4:ac:19:2f:95:ee:89:19:5e:74:f1:a6:\n    41:a6:1f:d2:06:bd:f1:9b:3c:a5:ad:51:28:3b:86:\n    e4:78:f0:c8:69:00:73:75:43:51:87:a1:43:1b:b2:\n    0d:1b:e6:1b:8e:d6:5f:62:04:b6:52:33:f7:82:0e:\n    3b:e0:47:b3:b5:bb:47:80:fc:30:d9:a5:1f:9e:52:\n    18:b5:7a:aa:b7:d6:d7:4a:b6:f2:c0:9e:04:33:f3:\n    af:4a:bd:ba:4b:54:f1:ba:1f:2d:a7:97:c2:f6:d9:\n    e0:4e:66:f5:ca:99:e5:52:73:ad:9e:50:35:24:af:\n    fd:a1\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME Signing CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'E7:36:F6:3A:B4:1E:50:3E:B0:C7:A9:D7:D5:9A:E2:AA:80:A6:0F:BC',
            },
        ),
        orphan => OpenXPKI::Test::PEM->new(
            label => "Orphan cert with unknown issuer",
            database => {
                authority_key_identifier => '92:D3:F3:20:B3:55:1B:5B:C1:7F:1C:68:F8:99:76:5B:EC:78:9C:F5',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDejCCAmKgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxEDAOBgNVBAsMB1Rlc3Qg\nQ0ExGDAWBgNVBAMMD0FDTUUgU2lnbmluZyBDQTAeFw0xNzAxMjQyMDI5MzFaFw0x\nODAxMjQyMDI5MzFaMFcxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/Is\nZAEZFghPcGVuWFBLSTEQMA4GA1UECwwHVGVzdCBDQTEUMBIGA1UEAwwLQUNNRSBD\nbGllbnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCrh91Nym0h5+Fp\nFdzkG2FdOU0INuksNROXj3Al9aDPNfCuo+5MdWfCszgGPSkUMy5wUgR9ijSMr1b6\nmNFA6ahQsqYekh6JAaU9SeaQ8BS9H8Azf02QFwbCIIIA1iXnCd+lqZ7q3LnjvyaO\niSEvFpDrGdMeqvkY3KGL//wJxas6agUtAth+Jr+hlOEv5Qr7RWehgH7MdikT6R/7\nPYySPK0bGQQ51JSeeCkaZV9LYDLz3EaFu/zUnl/G8UPImW4vfXdB5zohwp+dqMKF\n2z12KLmh8Eq3ngszI+x3Q4dbD/ruztzgeD8loIT4qn72ZOcV093ggLJ9PCE4vFX3\n/U7LXUD/AgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFAWi7Q7GAKsnanH5\nY42VaeTSrTcRMB8GA1UdIwQYMBaAFJLT8yCzVRtbwX8caPiZdlvseJz1MA0GCSqG\nSIb3DQEBCwUAA4IBAQC83uo0/0cPmeAPsH1ERlXXQmqP6JDyAZWcbTk1UWFgchKD\n/A/ROTVznFUyvZwpQiSdmo1//yxUdhyMgxm8E2rDlUkBnYPbQJwfpZReqq5mABoP\nOj2R7zK5j4l1KLtkt7jEPLebCzywBO5O+iFee7hKac2CoNoKemDI7udqqJQKzKEM\nqATGQNMtBxKoiE0vpUN+hnaM5ofZdlnTtWaKALVoxWKSDow68EeVBHEVoqEN68fa\n48itJqzcA/lvK8ZRtYLqNMET0iPAZOfmmKO4nTK5e7ODFIAFszJU0del29iplaLS\nXQEAw0s5fnpf+zCD8FeiQH+yuBkPFWuDBpjUHJUS\n-----END CERTIFICATE-----\n",
                identifier => 'Ej5l-zFmlW1n_pVNrJPNYpo5Vu0',
                issuer_dn => 'CN=ACME Signing CA,OU=Test CA,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '',
                loa => undef,
                notafter => '1516825771',
                notbefore => '1485289771',
                pki_realm => undef,
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:ab:87:dd:4d:ca:6d:21:e7:e1:69:15:dc:e4:1b:\n    61:5d:39:4d:08:36:e9:2c:35:13:97:8f:70:25:f5:\n    a0:cf:35:f0:ae:a3:ee:4c:75:67:c2:b3:38:06:3d:\n    29:14:33:2e:70:52:04:7d:8a:34:8c:af:56:fa:98:\n    d1:40:e9:a8:50:b2:a6:1e:92:1e:89:01:a5:3d:49:\n    e6:90:f0:14:bd:1f:c0:33:7f:4d:90:17:06:c2:20:\n    82:00:d6:25:e7:09:df:a5:a9:9e:ea:dc:b9:e3:bf:\n    26:8e:89:21:2f:16:90:eb:19:d3:1e:aa:f9:18:dc:\n    a1:8b:ff:fc:09:c5:ab:3a:6a:05:2d:02:d8:7e:26:\n    bf:a1:94:e1:2f:e5:0a:fb:45:67:a1:80:7e:cc:76:\n    29:13:e9:1f:fb:3d:8c:92:3c:ad:1b:19:04:39:d4:\n    94:9e:78:29:1a:65:5f:4b:60:32:f3:dc:46:85:bb:\n    fc:d4:9e:5f:c6:f1:43:c8:99:6e:2f:7d:77:41:e7:\n    3a:21:c2:9f:9d:a8:c2:85:db:3d:76:28:b9:a1:f0:\n    4a:b7:9e:0b:33:23:ec:77:43:87:5b:0f:fa:ee:ce:\n    dc:e0:78:3f:25:a0:84:f8:aa:7e:f6:64:e7:15:d3:\n    dd:e0:80:b2:7d:3c:21:38:bc:55:f7:fd:4e:cb:5d:\n    40:ff\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME Client,OU=Test CA,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '05:A2:ED:0E:C6:00:AB:27:6A:71:F9:63:8D:95:69:E4:D2:AD:37:11',
            },
        ),
    };
}

__PACKAGE__->meta->make_immutable;
