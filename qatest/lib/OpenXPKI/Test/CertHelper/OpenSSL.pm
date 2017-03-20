package OpenXPKI::Test::CertHelper::OpenSSL;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::CertHelper::OpenSSL - Test helper that creates certificates
using the OpenSSL binary.

=head1 DESCRIPTION

This class is not intended for direct use. Please use the class methods in
L<OpenXPKI::Test::CertHelper> instead.

=cut

# Core modules
use File::Temp qw( tempdir );
use File::Path qw( make_path );
use MIME::Base64;
use IPC::Open3 qw( open3 );

################################################################################
# Constructor attributes
has 'basedir'              => ( is => 'rw', default => sub { return tempdir( CLEANUP => 1 ) } );
has 'verbose'              => ( is => 'rw', default => 0 );
has 'stateOrProvinceName'  => ( is => 'rw', default => 'n/a' );
has 'localityName'         => ( is => 'rw', default => 'n/a' );
has '0_organizationName'   => ( is => 'rw', default => 'n/a' );
has 'organizationUnitName' => ( is => 'rw', default => 'n/a' );
has 'countryName'          => ( is => 'rw', default => 'XX' );
has 'commonName'           => ( is => 'rw', default => 'test.openxpki.org' );
has 'emailAddress'         => ( is => 'rw', default => 'test@test.openxpki.org' );
has 'password'             => ( is => 'rw', default => 'oxi' );

has 'filepath_opensslconf' => ( is => 'rw', lazy => 1, default => sub { shift->basedir."/openssl.conf" } );
has 'filepath_key_der'     => ( is => 'rw', lazy => 1, default => sub { shift->basedir."/key.der" } );
has 'filepath_cert_der'    => ( is => 'rw', lazy => 1, default => sub { shift->basedir."/crt.der" } );
has 'filepath_cert_pem'    => ( is => 'rw', lazy => 1, default => sub { shift->basedir."/crt.pem" } );

# will contain the certificate in PEM format after create_cert() was called
has 'cert_pem' => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        # slurp
        return do { local $/; open my $fh, '<', $self->filepath_cert_pem; <$fh> };
    }
);

=head1 METHODS

=cut

=head2 _openssl_conf

Returns an array containing the contents of the openssl.conf. Named
parameters may be specified to set specific values. See the code for
a list of the supported key names.

=cut

sub _openssl_conf {
    my ($self) = @_;
    my @opensslconf = ();
    my @attrs = qw( stateOrProvinceName localityName 0_organizationName organizationUnitName commonName emailAddress countryName );

    my @opensslconffiles = qw( /opt/local/etc/openssl/openssl.cnf /usr/lib/ssl/openssl.cnf );
    unshift @opensslconffiles, $ENV{OPENSSL_CONF} if $ENV{OPENSSL_CONF};

    for my $file (@opensslconffiles) {
        open(my $fh, $file) or next;
        while ( my $ln = <$fh> ) {
            next if $ln =~ m/^\S+_default\W/;
            next if $ln =~ m/^\S+_max\W/;
            next if $ln =~ m/^\S+_min\W/;

            $ln .= "prompt = no\n" if $ln =~ m/^distinguished_name/;
            foreach my $key ( @attrs ) {
                my $patt = $key; $patt =~ s/_/./g;
                $ln = sprintf("%s = %s\n", $patt, $self->$key) if $ln =~ m/^\Q$patt\E\W/;
            }
            push @opensslconf, $ln;
        }
        last;
    }
    return @opensslconf;
}

=head2 create_cert

Calls OpenSSL to create the CSR and the certificate.

=cut

sub create_cert {
    my $self = shift;

    my $basedir = $self->basedir;

    my $path_opensslconf = $self->filepath_opensslconf;

    unless (-e $basedir) {
        my $err = [];
        make_path($basedir, { error => \$err} );
        if ( @{ $err } ) {
            for my $diag (@{ $err }) {
                my ($file, $message) = %{ $diag };
                die sprintf("%s: %s", $file ? "Error making dir $file" : "Error running make_path", $message);
            }
        }
    }

    my $cnf;
    open  $cnf, '>' . $path_opensslconf or die "Could not open '$path_opensslconf': $!";
    print $cnf $self->_openssl_conf     or die "Could not write to '$path_opensslconf': $!";
    close $cnf                          or die "Could not close '$path_opensslconf': $!";

    # Certificate Signing Request
    my @cmd = (
        'openssl',  'req',
        '-newkey',  'rsa:2048',
        '-new',     '-days',
        '400',      '-x509',
        '-config',  $path_opensslconf,
        '-keyout',  $self->filepath_key_der,
        '-out',     $self->filepath_cert_der,
        '-outform', 'der',
    );

    if ($self->password) {
        $ENV{OXI_TEST_OPENSSL_PASSWORD} = $self->password;
        push @cmd, '-passout' => 'env:OXI_TEST_OPENSSL_PASSWORD';
    }

    warn "createcert() - ", join(', ', @cmd) if $self->verbose;
    # Silence STDOUT unless we are in verbose mode
    my ($pid, $rc);
    $pid = open3(0, $ENV{TEST_VERBOSE} ? ">&1" : 0, 0, @cmd); waitpid($pid, 0);
    $rc = $? >> 8;
    die "Error running " . join(' ', @cmd) if $rc;

    delete $ENV{OXI_TEST_OPENSSL_PASSWORD} if $self->password;

    # Certificate
    @cmd = (
        'openssl',  'x509',
        '-in',      $self->filepath_cert_der,
        '-inform',  'DER',
        '-out',     $self->filepath_cert_pem,
        '-outform', 'PEM',
    );

    $pid = open3(0, $ENV{TEST_VERBOSE} ? ">&1" : 0, 0, @cmd); waitpid($pid, 0);
    $rc = $? >> 8;
    die "Error running " . join(' ', @cmd) if $rc;

    return $self;
}

__PACKAGE__->meta->make_immutable;
