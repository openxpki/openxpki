package OpenXPKI::Test::CertHelper;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::CertHelper - Helper class for tests to quickly create
certificates etc.

=head1 SYNOPSIS

This class is an entry point for other classes in the
C<OpenXPKI::Test::CertHelper::*> namespace and provides three ways to interact
with test certificates:

=over

=item 1. Insert fixed test certificates into the database with L</via_database>.

=item 2. Create certificates on disk (default: in a temporaray directory) with
L</via_openssl>.

=item 3. Create certificates in OpenXPKI with L</via_workflow>.

=back

=cut

# Project modules
use OpenXPKI::Test::CertHelper::Database;
use OpenXPKI::Test::CertHelper::OpenSSL;
use OpenXPKI::Test::CertHelper::Workflow;

################################################################################
# METHODS
#

=head2 via_database

Class method that inserts all fixed test certificates into the database and
returns an instance of L<OpenXPKI::Test::CertHelper::Database>.

    my $db = OpenXPKI::Test::CertHelper->via_database; # instance of OpenXPKI::Test::CertHelper::Database
    my $cert = $db-E<gt>cert("acme2_client");          # instance of OpenXPKI::Test::CertHelper::Database::PEM
    print $cert->id, "\n";     # certificate identifier
    print $cert->data, "\n";   # PEM encoded certificate

There is a set of predefined test certificates:

    $db-E<gt>cert("acme_root")         # ACME self signed Root Certificate
    $db-E<gt>cert("acme_signer")       # ACME Signing CA (signed by Root Certificate)
    $db-E<gt>cert("acme_client")       # ACME client (signed by Signing CA)
    $db-E<gt>cert("acme2_root")        # ACME-2 self signed Root Certificate
    $db-E<gt>cert("acme2_signer")      # ACME-2 Signing CA (signed by Root Certificate)
    $db-E<gt>cert("acme2_client")      # ACME-2 client (signed by Signing CA)
    $db-E<gt>cert("expired_root")      # Expired Root Certificate
    $db-E<gt>cert("expired_signer")    # Expired Signing CA
    $db-E<gt>cert("orphan")            # Client Certificate withouth Signing or Root CA)

=cut
sub via_database {
    my $class = shift;
    my $helper = OpenXPKI::Test::CertHelper::Database->new(@_);
    $helper->insert_all;
    return $helper;
}

=head2 via_openssl

Class method (does not require instantiation) that creates a CSR and the
certificate on disk using the OpenSSL binary.

    my $cert = OpenXPKI::Test::CertHelper-E<gt>via_openssl(
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

Possible arguments are all attributes of L<OpenXPKI::Test::CertHelper::OpenSSL>.

Returns the instance of L<OpenXPKI::Test::CertHelper::OpenSSL>.

=cut
sub via_openssl {
    my $class = shift;
    my $helper = OpenXPKI::Test::CertHelper::OpenSSL->new(@_);
    $helper->create_cert;
    return $helper;
}

=head2 via_workflow

Class method (does not require instantiation) that creates a CSR and the
certificate in OpenXPKI via workflows.

    my $cert_info = OpenXPKI::Test::CertHelper-E<gt>via_workflow(
        tester => $test,                      # Instance of L<OpenXPKI::Test::More> (required)
        hostname => "myhost",                 # Hostname for certificate (I<Str>, required)
        hostname2 => [],                      # List of additional hostnames (I<ArrayRef[Str]>, optional)
        profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER", # Certificate profile (I<Str>, optional, default: "I18N_OPENXPKI_PROFILE_TLS_SERVER")
        requestor_gname => "tom",             # Surname of person requesting cert (I<Str>, optional)
        requestor_name => "table",            # Name of person requesting cert (I<Str>, optional)
        requestor_email => "tom@table.local", #  Email of person requesting cert (I<Str>, optional)
    );
    diag $cert_info->{identifier};

Possible arguments are all attributes of L<OpenXPKI::Test::CertHelper::Workflow>.

Returns a HashRef containing some info about the created certificate.

=cut
sub via_workflow {
    my $class = shift;
    my $helper = OpenXPKI::Test::CertHelper::Workflow->new(@_);
    return $helper->create_cert; # returns certificate info HashRef
}

__PACKAGE__->meta->make_immutable;
