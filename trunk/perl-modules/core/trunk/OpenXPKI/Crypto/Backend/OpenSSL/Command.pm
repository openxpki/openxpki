## OpenXPKI::Crypto::Backend::OpenSSL::Command
## (C)opyright 2005 Michael Bell

use strict;
use warnings;
use utf8;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_random;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_key;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs10;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs12;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_key;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_crl;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_encrypt;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_decrypt;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain;

package OpenXPKI::Crypto::Backend::OpenSSL::Command;

use OpenXPKI::Debug;
use OpenXPKI qw(read_file write_file get_safe_tmpfile);
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use File::Temp;
use File::Spec;
use POSIX qw(strftime);
use OpenXPKI::Exception;
use English;

sub new
{
    ##! 1: "start"
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = shift;
    bless $self, $class;

    ##! 2: "check engine availability"
    if (not exists $self->{ENGINE} or not ref $self->{ENGINE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_ENGINE");
    }

    ##! 2: "check config availability"
    if (not exists $self->{CONFIG} or not ref $self->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_CONFIG");
    }

    ##! 2: "check XS availability"
    if (not exists $self->{XS} or not ref $self->{XS})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_XS");
    }

    ##! 2: "$self->{TMP} will be checked by the central OpenSSL module"
    if (not $self->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_TEMPORARY_DIRECTORY_UNAVAILABLE");
    }

    ##! 1: "end"
    return $self;
}

sub set_tmpfile
{
    my $self = shift;
    my $keys = { @_ };

    foreach my $key (keys %{$keys})
    {
	push @{$self->{CLEANUP}->{FILE}}, $keys->{$key};

        $self->{$key."FILE"} = $keys->{$key};
    }
    return 1;
}

sub get_tmpfile
{
    my $self = shift;

    if (scalar(@_) == 0) {
        my $filename = $self->get_safe_tmpfile ({TMP => $self->{TMP}});
	push @{$self->{CLEANUP}->{FILE}}, $filename;
	return $filename;
    }
    else
    {
	while (my $arg = shift) {
            my $filename = $self->get_safe_tmpfile ({TMP => $self->{TMP}});
	    $self->set_tmpfile($arg => $filename);
	}
    }
}

sub set_env
{
    my $self = shift;
    my $keys = { @_ };

    foreach my $key (keys %{$keys})
    {
	push @{$self->{CLEANUP}->{ENV}}, $key;
        $ENV{$key} = $keys->{$key};
    }
    return 1;
}

sub cleanup
{
    my $self = shift;

    $self->{CONFIG}->cleanup() if ($self->{CONFIG});

    foreach my $file (@{$self->{CLEANUP}->{FILE}})
    {
        if (-e $file) 
	{
	    unlink $file;
	}
        if (-e $file)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CLEANUP_FILE_FAILED",
                params  => {"FILENAME" => $file});
        }
    }

    foreach my $variable (@{$self->{CLEANUP}->{ENV}})
    {
        delete $ENV{$variable};
        if (exists $ENV{$variable})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CLEANUP_ENV_FAILED",
                params  => {"VARIABLE" => $variable});
        }
    }

    return 1;
}

sub get_openssl_dn
{
    my $self = shift;
    my $dn   = shift;

    ##! 2: "rfc2253: $dn"
    my $dn_obj = OpenXPKI::DN->new ($dn);
    if (not $dn_obj) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_DN_FAILURE",
            params   => {"DN" => $dn});
    }

    ## this is necessary because OpenSSL needs the utf8 bytes
    #pack/unpack is too slow, try to use "use utf8;"
    #$dn = pack "C*", unpack "C0U*", $dn_obj->get_openssl_dn ();
    $dn = $dn_obj->get_openssl_dn ();
    ##! 2: "OpenSSL X.500: $dn"

    return $dn;
}

sub DESTROY
{
    my $self = shift;
    $self->cleanup();
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command

=head1 Description

This function is the base class for all available OpenSSL commands
from the OpenSSL command line interface. All commands are executed
inside of the OpenSSL shell.

=head1 Functions

=head2 new

is the constructor. The ENGINE and the TMP parameter must be always
present. All other parameters will be passed without any checks to
the hash of the class instance. The real checks must be implemented
by the commands itself.

=head2 set_tmpfile

expects a hash with prefix infront of FILE and the filename which is
a tmpfile. Example:

$self->set_tmpfile ("IN" => "/tmp/example.txt")

mapped to

$self->{INFILE} = "/tmp/example.txt";

All temporary file are cleaned up automatically.

=head2 get_tmpfile

If called without arguments this method creates a temporary file and 
returns its filename:

  my $tmpfile = $self->get_tmpfile();

If called with one or more arguments, the method creates a temporary
file for each argument specified and calls $self->set_tmpfile() for
this argument.

Calling

  $self->get_tmpfile(IN, OUT);

is equivalent to

  $self->set_tmpfile( IN  => $self->get_tmpfile(),
                      OUT => $self->get_tmpfile() );

All temporary file are set to mode 0600 and are cleaned up automatically.

=head2 set_env

This function works exactly like set_tmpfile but without any
automatical prefixes or suffixes. The environment is also
cleaned up automatically.

=head2 cleanup

performs the cleanup of any temporary stuff like files from
set_tmpfile and environment variables from set_env.

=head2 get_openssl_dn

expects a RFC2253 compliant DN and returns an OpenSSL DN.
