package OpenXPKI::Test::QA::CertHelper;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::QA::CertHelper - Helper class for tests to quickly create
certificates etc.

=head1 SYNOPSIS

This class is an entry point for other classes in the
C<OpenXPKI::Test::QA::CertHelper::*> namespace and provides three ways to interact
with test certificates:

=over

=item 1. Insert fixed test certificates into the database with L</via_database>.

=item 2. Create certificates on disk (default: in a temporaray directory) with
L</via_openssl>.

=item 3. Create certificates in OpenXPKI with L</via_workflow>.

=back

=cut

# Project modules
use OpenXPKI::Test::QA::CertHelper::OpenSSL;
use OpenXPKI::Test::QA::CertHelper::Workflow;

################################################################################
# METHODS
#

=head2 via_openssl

Class method (does not require instantiation) that creates a CSR and the
certificate on disk using the OpenSSL binary.

    my $cert = OpenXPKI::Test::QA::CertHelper-E<gt>via_openssl(
        basedir => '/tmp',  # default to an auto-generated temp dir
        verbose => 0,
        stateOrProvinceName => 'bla',
        localityName => 'bla',
        0_organizationName => 'bla',
        organizationUnitName => 'bla',
        countryName => 'bla',
        commonName => 'bla',
        emailAddress => 'bla',
        password => 'pass',
    );
    print $cert->cert_pem;

Possible arguments are all attributes of L<OpenXPKI::Test::QA::CertHelper::OpenSSL>.

Returns the instance of L<OpenXPKI::Test::QA::CertHelper::OpenSSL>.

=cut
sub via_openssl {
    my $class = shift;
    my $helper = OpenXPKI::Test::QA::CertHelper::OpenSSL->new(@_);
    $helper->create_cert;
    return $helper;
}

=head2 via_workflow

Class method (does not require instantiation) that creates a CSR and the
certificate in OpenXPKI via workflows.

    my $cert_info = OpenXPKI::Test::QA::CertHelper-E<gt>via_workflow(
        tester => $test,                      # Instance of L<OpenXPKI::Test::QA::More> (required)
        hostname => "myhost",                 # Hostname for certificate (I<Str>, required)
        application_name => "myapp",          # Name of the application (I<Str>, required for client profile)
        hostname2 => [],                      # List of additional hostnames (I<ArrayRef[Str]>, optional for server profile)
        profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER", # Certificate profile (I<Str>, optional, default: "I18N_OPENXPKI_PROFILE_TLS_SERVER")
        requestor_gname => "tom",             # Surname of person requesting cert (I<Str>, optional)
        requestor_name => "table",            # Name of person requesting cert (I<Str>, optional)
        requestor_email => "tom@table.local", #  Email of person requesting cert (I<Str>, optional)
    );
    diag $cert_info->{identifier};

Possible arguments are all attributes of L<OpenXPKI::Test::QA::CertHelper::Workflow>.

Returns a HashRef containing some info about the created certificate.

=cut
sub via_workflow {
    my $class = shift;
    my $helper = OpenXPKI::Test::QA::CertHelper::Workflow->new(@_);
    return $helper->create_cert; # returns certificate info HashRef
}

__PACKAGE__->meta->make_immutable;
