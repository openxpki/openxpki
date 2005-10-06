## OpenXPKI::Crypto::OpenSSL::Command
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

use OpenXPKI::Crypto::OpenSSL::Command::create_random;
use OpenXPKI::Crypto::OpenSSL::Command::create_rsa;
use OpenXPKI::Crypto::OpenSSL::Command::create_dsa;
use OpenXPKI::Crypto::OpenSSL::Command::create_pkcs10;
use OpenXPKI::Crypto::OpenSSL::Command::create_cert;
use OpenXPKI::Crypto::OpenSSL::Command::create_pkcs12;
use OpenXPKI::Crypto::OpenSSL::Command::issue_cert;
use OpenXPKI::Crypto::OpenSSL::Command::issue_crl;

use OpenXPKI::Crypto::OpenSSL::Command::convert_key;
use OpenXPKI::Crypto::OpenSSL::Command::convert_pkcs10;
use OpenXPKI::Crypto::OpenSSL::Command::convert_cert;
use OpenXPKI::Crypto::OpenSSL::Command::convert_crl;

use OpenXPKI::Crypto::OpenSSL::Command::pkcs7_sign;
use OpenXPKI::Crypto::OpenSSL::Command::pkcs7_encrypt;
use OpenXPKI::Crypto::OpenSSL::Command::pkcs7_decrypt;
use OpenXPKI::Crypto::OpenSSL::Command::pkcs7_verify;
use OpenXPKI::Crypto::OpenSSL::Command::pkcs7_get_chain;

package OpenXPKI::Crypto::OpenSSL::Command;

use OpenXPKI qw(i18nGettext debug set_error errno errval read_file write_file);
use OpenXPKI::DN;
use Date::Parse;
use POSIX qw(strftime);

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = { @_ };
    bless $self, $class;
    #$self->{DEBUG} = 1;

    ## re-organize engine stuff

    if (not exists $self->{ENGINE} or not ref $self->{ENGINE})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_ENGINE");
        return undef;
    }

    if (not exists $self->{TMP})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_TMP");
        return undef;
    }

    return $self;
}

sub cleanup
{
    my $self = shift;

    foreach my $file (keys %{$self->{CLEANUP}->{FILE}})
    {
        unlink $self->{CLEANUP}->{FILE}->{$file};
        if (-e $self->{CLEANUP}->{FILE}->{$file})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CLEANUP_FILE_FAILED",
                              "__FILENAME__", $self->{CLEANUP}->{FILE}->{$file});
            return undef;
        }
    }

    foreach my $variable (keys %{$self->{CLEANUP}->{ENV}})
    {
        delete $ENV{$self->{CLEANUP}->{ENV}->{$variable}};
        if (exists $ENV{$self->{CLEANUP}->{ENV}->{$variable}})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_CLEANUP_ENV_FAILED",
                              "__VARIABLE__", $self->{CLEANUP}->{ENV}->{$variable});
            return undef;
        }
    }

    return 1;
}

sub __get_openssl_dn
{
    my $self = shift;
    my $dn   = shift;

    $self->debug ("rfc2253: $dn");
    my $dn_obj = OpenXPKI::DN->new ($dn);
    if (not $dn_obj) {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_DN_FAILURE",
                          "__DN__", $dn,
                          "__ERRVAL__", $OpenXPKI::DN::errval);
        return undef;
    }

    ## this is necessary because OpenSSL needs the utf8 bytes
    $dn = pack "C*", unpack "C0U*", $dn_obj->get_openssl_dn ();
    $self->debug ("OpenSSL X.500: $dn");

    return $dn;
}

sub __get_config_variable
{
    my $self = shift;
    my $keys = { @_ };

    my $name     = $keys->{NAME};
    my $config   = $keys->{CONFIG};
    my $filename = $keys->{FILENAME};
    return undef
        if (not $config and
            not $self->read_file ($filename));

    return "" if ($config !~ /^(.*\n)*\s*${name}\s*=\s*([^\n^#]+).*$/s);

    my $result = $config;
       $result =~ s/^(.*\n)*\s*${name}\s*=\s*([^\n^#]+).*$/$2/s;
       $result =~ s/[\r\n\s]*$//s;
    if ($result =~ /\$/)
    {
        my $dir = $result;
           $dir =~ s/^.*\$([a-zA-Z0-9_]+).*$/$1/s;
        my $value = $self->__get_config_variable (NAME => $dir, CONFIG => $config);
        return undef if (not defined $dir);
        $result =~ s/\$$dir/$value/g;
    }
    return $result;
}

sub __get_openssl_time
{
    my $self = shift;
    my $time = shift;

    $time = str2time ($time);
    $time = [ gmtime ($time) ];
    $time = POSIX::strftime ("%g%m%d%H%M%S",@{$time})."Z";

    return $time;
}

1;
