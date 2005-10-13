## OpenXPKI::Crypto::PKCS7
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::PKCS7;

use Date::Parse;
use OpenXPKI::Exception;

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;
    $self = {};
    bless $self, $class;

    my $keys = { @_ };
    $self->{DEBUG}   = 1 if ($keys->{DEBUG});
    $self->{PKCS7}   = $keys->{PKCS7};
    $self->{CONTENT} = $keys->{CONTENT};
    $self->{TOKEN}   = $keys->{TOKEN};

    if (not $self->{PKCS7} and not $self->{CONTENT})
    {
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_CRL_NEW_MISSING_DATA");
    }
    if (not $self->{TOKEN})
    {
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_CRL_NEW_MISSING_TOKEN");
    }

    return $self;
}

sub sign
{
    my $self = shift;
    my $keys = { @_ };

    my %params = (DEBUG => $self->{DEBUG});
    $params{CONTENT}    = $self->{CONTENT}    if (exists $self->{CONTENT});
    $params{CERT}       = $keys->{CERT}       if (exists $keys->{CERT});
    $params{KEY}        = $keys->{KEY}        if (exists $keys->{KEY});
    $params{PASSWD}     = $keys->{PASSWD}     if (exists $keys->{PASSWD});
    $params{USE_ENGINE} = $keys->{USE_ENGINE} if (exists $keys->{USE_ENGINE});
    $params{ENC_ALG}    = $keys->{ENC_ALG}    if (exists $keys->{ENC_ALG});
    $params{DETACH}     = $keys->{DETACH}     if (exists $keys->{DETACH});

    $self->{PKCS7} = $self->{TOKEN}->command ("pkcs7_sign", %params);
    return $self->{PKCS7};
}

sub verify
{
    my $self = shift;
    my $keys = { @_ };

    my %params = (DEBUG => $self->{DEBUG});
    $params{PKCS7}      = $self->{PKCS7};
    $params{CONTENT}    = $self->{CONTENT}    if (exists $self->{CONTENT});
    $params{CHAIN}      = $keys->{CHAIN}      if (exists $keys->{CHAIN});
    $params{USE_ENGINE} = $keys->{USE_ENGINE} if (exists $keys->{USE_ENGINE});
    $params{NO_VERIFY}  = $keys->{NO_VERIFY}  if (exists $keys->{NO_VERIFY});

    $self->{SIGNER} = $self->{TOKEN}->command ("pkcs7_verify", %params);
    return $self->{SIGNER};
}

sub encrypt
{
    my $self = shift;
    my $keys = { @_ };

    my %params = (DEBUG => $self->{DEBUG});
    $params{CONTENT}    = $self->{CONTENT};
    $params{CERT}       = $keys->{CERT}       if (exists $keys->{CERT});
    $params{USE_ENGINE} = $keys->{USE_ENGINE} if (exists $keys->{USE_ENGINE});
    $params{ENC_ALG}    = $keys->{ENC_ALG}    if (exists $keys->{ENC_ALG});

    $self->{PKCS7} = $self->{TOKEN}->command ("pkcs7_encrypt", %params);
    return $self->{PKCS7};
}

sub decrypt
{
    my $self = shift;
    my $keys = { @_ };

    my %params = (DEBUG => $self->{DEBUG});
    $params{PKCS7}      = $self->{PKCS7};
    $params{CERT}       = $keys->{CERT}       if (exists $keys->{CERT});
    $params{KEY}        = $keys->{KEY}        if (exists $keys->{KEY});
    $params{PASSWD}     = $keys->{PASSWD}     if (exists $keys->{PASSWD});
    $params{USE_ENGINE} = $keys->{USE_ENGINE} if (exists $keys->{USE_ENGINE});

    $self->{CONTENT} = $self->{TOKEN}->command ("pkcs7_decrypt", %params);
    return $self->{CONTENT};
}

sub get_chain
{
    my $self = shift;
    my $keys = { @_ };
    return $self->{CHAIN} if ($self->{CHAIN});

    $self->verify() if (not exists $self->{SIGNER});

    my %params = (DEBUG => $self->{DEBUG});
    $params{PKCS7}      = $self->{PKCS7};
    $params{SIGNER}     = $self->{SIGNER};
    $params{USE_ENGINE} = $keys->{USE_ENGINE} if (exists $keys->{USE_ENGINE});
    $self->{CHAIN} = $self->{TOKEN}->command("pkcs7_get_chain", %params);
    ## the chain is already sorted
    $self->{CHAIN} = [ split /\n\n/, $self->{CHAIN} ];
    return $self->{CHAIN};
}

sub get_signer
{
    my $self = shift;
    return $self->{SIGNER};
}

sub get_content
{
    my $self = shift;
    return $self->{CONTENT};
}

sub get_pkcs7
{
    my $self = shift;
    return $self->{PKCS7};
}

1;
