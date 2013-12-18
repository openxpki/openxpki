# CertHelper
#
# IMPORTANT:
#
#   This is just a helper class for test certs used in various unit tests.
#   Please don't use this for production stuff!!!
#

=head1 NAME

CertHelper

=head1 SYNOPSIS

    use CertHelper;

    my $ch = CertHelper->new(
        commonName => 'my.commonname.org',
        basedir => 't/mycert.d',
    );

    $ch->createcert;

=cut

package CertHelper;
use Moose;

use File::Temp();
use File::Path qw(make_path);
use MIME::Base64;

has 'basedir'              => ( is => 'rw' );
has 'verbose'              => ( is => 'rw', default => 0 );
has 'stateOrProvinceName'  => ( is => 'rw', default => 'n/a' );
has 'localityName'         => ( is => 'rw', default => 'n/a' );
has '0_organizationName'   => ( is => 'rw', default => 'n/a' );
has 'organizationUnitName' => ( is => 'rw', default => 'n/a' );
has 'countryName' => ( is => 'rw', default => 'XX' );
has 'commonName'           => ( is => 'rw', default => 'test.openxpki.org' );
has 'emailAddress' => ( is => 'rw', default => 'test@test.openxpki.org' );
has 'pass_type' => ( is => 'rw' );
has 'pass_val' => ( is => 'rw' );

=head1 METHODS

=cut

=head2 opensslconf

Returns an array containing the contents of the openssl.conf. Named
parameters may be specified to set specific values. See the code for
a list of the supported key names.

=cut

sub opensslconf {
    my $self = shift;

    my %params = @_;

    # Default values for params...
    foreach my $key (
        qw( stateOrProvinceName localityName 0_organizationName organizationUnitName commonName emailAddress countryName)
      )
    {
        $params{$key} ||= $self->$key();
    }

    my @opensslconf = ();

    my @opensslconffiles = qw( /opt/local/etc/openssl/openssl.cnf /usr/lib/ssl/openssl.cnf );
    if ( $ENV{OPENSSL_CONF} ) {
        unshift @opensslconffiles, $ENV{OPENSSL_CONF};
    }

    foreach my $file ( @opensslconffiles ) {
        if ( open( my $fh, $file ) ) {

            while ( my $ln = <$fh> ) {
                $ln .= "prompt = no\n" if $ln =~ m/^distinguished_name/;

                foreach my $key ( keys %params ) {
                    my $patt = $key;
                    $patt =~ s/_/./g;
                    if ( $ln =~ m/^$patt\s/ ) {
                        $ln = $patt . ' = ' . $params{$key} . "\n";
                    }
                }
                $ln = "" if $ln =~ m/^\S+_default\s/;
                $ln = "" if $ln =~ m/^\S+_max\s/;
                $ln = "" if $ln =~ m/^\S+_min\s/;
                push @opensslconf, $ln;
            }
            last;
        }
    }
    return @opensslconf;

}

sub createcert {
    my $self = shift;

    my $basedir = $self->basedir;
    my $config  = {};

    $config->{opensslconf} = $basedir . '/openssl.conf';
    $config->{key_der}     = $basedir . '/key.der';
    $config->{crt_der}     = $basedir . '/crt.der';
    $config->{crt_pem}     = $basedir . '/crt.pem';
    #$config->{key_pas}     = $basedir . '/key.pas';

    if ( not $self->pass_type and -f $basedir . '/key.pas' ) {
        $self->pass_type( 'file' );
        $self->pass_val( $basedir . '/key.pas' );
    }

    make_path($basedir, { error => \my $err} );
    if ( @{ $err } ) {
        for my $diag (@{ $err }) {
            my ($file, $message) = %{ $diag };
            if ( $file eq '' ) {
                die "Error running make_path: $message";
            } else {
                die "Error making dir $file: $message";
            }
        }
    }

    my $cnf;
    open( $cnf, '>' . $config->{opensslconf} )
      or die "Open '", $config->{opensslconf}, " failed: $!";
    print( $cnf $self->opensslconf() )
      or die "Error printing to ", $config->{opensslconf}, ": $!";
    close($cnf) or die "Error closing ", $config->{opensslconf}, ": $!";

    my @cmd = (
        'openssl',  'req',
        '-newkey',  'rsa:2048',
        '-new',     '-days',
        '400',      '-x509',
        '-config',  $config->{opensslconf},
        '-keyout',  $config->{key_der},
        '-out',     $config->{crt_der},
        '-outform', 'der',
    );
    if ( $self->pass_type ) {
        push @cmd, '-passout', $self->pass_type() . ':' . $self->pass_val();
    }

    warn "createcert() - ", join(', ', @cmd) if $self->verbose();
    my $rc = system(@cmd);
    $rc >>= 8;

    if ($rc) {
        die "Error running " . join( ' ', @cmd );
    }

    @cmd = (
        'openssl',  'x509',
        '-in',      $config->{crt_der},
        '-inform',  'DER',
        '-out',     $config->{crt_pem},
        '-outform', 'PEM',
    );
    warn "createcert() - ", join(', ', @cmd);
    $rc = system(@cmd);
    $rc >>= 8;
    if ($rc) {
        die "Error running " . join( ' ', @cmd );
    }

    return $self;
}

1;
