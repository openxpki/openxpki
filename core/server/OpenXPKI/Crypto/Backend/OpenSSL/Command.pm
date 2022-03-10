## OpenXPKI::Crypto::Backend::OpenSSL::Command
## (C)opyright 2005 Michael Bell

use strict;
use warnings;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_random;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs10;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkcs12;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::issue_crl;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkey;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs8;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_pkcs10;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_cert;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::convert_crl;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_sign;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_encrypt;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_decrypt;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_verify;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain;

use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_pkey;
use OpenXPKI::Crypto::Backend::OpenSSL::Command::create_params;

package OpenXPKI::Crypto::Backend::OpenSSL::Command;

use OpenXPKI::Debug;
use OpenXPKI::DN;
use OpenXPKI::FileUtils;
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

    ##! 2: "$self->{TMP} will be checked by the central OpenSSL module"
    if (not $self->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_TEMPORARY_DIRECTORY_UNAVAILABLE");
    }

    $self->{FU} = OpenXPKI::FileUtils->new({ TMP => $self->{TMP}});

    ##! 1: "end"
    return $self;
}

sub write_temp_file {

    my $self = shift;
    return $self->{FU}->write_temp_file( @_ );

}

sub get_outfile {

    my $self = shift;

    if (!$self->{OUTFILE}) {
        $self->{OUTFILE} = $self->get_tmpfile();
    }

    return $self->{OUTFILE};

}

sub get_tmpfile {
    my $self = shift;

    if (scalar(@_) != 0) {
       OpenXPKI::Exception->throw (
            message => "Call to get_tmpfile with arguments is no longer supported",
            params  => { ARGS => \@_ }
        );
    }

    return $self->{FU}->get_tmp_handle()->filename();

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

    $self->{FU}->cleanup();

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

    $dn = $dn_obj->get_openssl_dn();
    ##! 2: "OpenSSL X.500: $dn"
    return $dn;
}

sub get_result
{
    my $self = shift;
    # the result string passed from toolkit - not used
    my $toolkit_result = shift;

    if (!defined $self->{OUTFILE}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_OUTFILE_NOT_DEFINED",
        );
    }

    my $ret = $self->{FU}->read_file($self->get_outfile());
    if (!defined $ret || $ret eq '') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_OUTFILE_IS_EMPTY",
        );
    }

    return $ret;
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

=head2 get_tmpfile

Returns the filename of a temporary file.

  my $tmpfile = $self->get_tmpfile();

The files are created using File::Temp, handles are held by the command
base class to ensure the files remain available while the class exists and
are cleaned up when the command class is destroyed!

B<NOTE>: The synatax with arguments to create one or multiple filename in
the class namespace is no longer supported!

=head2 set_env

This function works exactly like set_tmpfile but without any
automatical prefixes or suffixes. The environment is also
cleaned up automatically.

=head2 cleanup

performs the cleanup of any temporary stuff like files from
get_tmpfile and environment variables from set_env.

=head2 get_openssl_dn

expects a RFC2253 compliant DN and returns an OpenSSL DN.

=head2 get_result

The default handler returns the content of OUTFILE. Must be overriden
in the child class if a different handling is required. Will throw an
exception if OUTFILE is not set, not readable or zero size.
