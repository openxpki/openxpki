## OpenXPKI::Crypto::PKCS7
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2003-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::PKCS7;

use OpenXPKI::Exception;

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;
    $self = {};
    bless $self, $class;

    my $keys = { @_ };
    $self->{PKCS7}   = $keys->{PKCS7};
    $self->{CONTENT} = $keys->{CONTENT};
    $self->{TOKEN}   = $keys->{TOKEN};

    if (not $self->{PKCS7} and not $self->{CONTENT})
    {
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_PKCS7_NEW_MISSING_DATA");
    }
    if (not $self->{TOKEN})
    {
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_PKCS7_NEW_MISSING_TOKEN");
    }

    return $self;
}

sub sign
{
    my $self = shift;
    my $keys = { @_ };

    my %params = ();
    $params{CONTENT}    = $self->{CONTENT}    if (exists $self->{CONTENT});
    $params{CERT}       = $keys->{CERT}       if (exists $keys->{CERT});
    $params{KEY}        = $keys->{KEY}        if (exists $keys->{KEY});
    $params{PASSWD}     = $keys->{PASSWD}     if (exists $keys->{PASSWD});
    $params{ENC_ALG}    = $keys->{ENC_ALG}    if (exists $keys->{ENC_ALG});
    $params{DETACH}     = $keys->{DETACH}     if (exists $keys->{DETACH});

    $self->{PKCS7} = $self->{TOKEN}->command ({COMMAND => "pkcs7_sign", %params});
    return $self->{PKCS7};
}

sub verify
{
    my $self = shift;
    my $keys = { @_ };

    my %params = ();
    $params{PKCS7}      = $self->{PKCS7};
    $params{CONTENT}    = $self->{CONTENT}    if (exists $self->{CONTENT});
    $params{CHAIN}      = $keys->{CHAIN}      if (exists $keys->{CHAIN});
    $params{NO_VERIFY}  = $keys->{NO_VERIFY}  if (exists $keys->{NO_VERIFY});

    $self->{SIGNER} = $self->{TOKEN}->command ({COMMAND => "pkcs7_verify", %params});
    return $self->{SIGNER};
}

sub encrypt
{
    my $self = shift;
    my $keys = { @_ };

    my %params = ();
    $params{CONTENT}    = $self->{CONTENT};
    $params{CERT}       = $keys->{CERT}       if (exists $keys->{CERT});
    $params{ENC_ALG}    = $keys->{ENC_ALG}    if (exists $keys->{ENC_ALG});

    $self->{PKCS7} = $self->{TOKEN}->command ({COMMAND => "pkcs7_encrypt", %params});
    return $self->{PKCS7};
}

sub decrypt
{
    my $self = shift;
    my $keys = { @_ };

    my %params = ();
    $params{PKCS7}      = $self->{PKCS7};
    $params{CERT}       = $keys->{CERT}       if (exists $keys->{CERT});
    $params{KEY}        = $keys->{KEY}        if (exists $keys->{KEY});
    $params{PASSWD}     = $keys->{PASSWD}     if (exists $keys->{PASSWD});

    $self->{CONTENT} = $self->{TOKEN}->command ({COMMAND => "pkcs7_decrypt", %params});
    return $self->{CONTENT};
}

sub get_chain
{
    my $self = shift;
    my $keys = { @_ };
    return $self->{CHAIN} if ($self->{CHAIN});

    $self->verify() if (not exists $self->{SIGNER});

    my %params = ();
    $params{PKCS7}      = $self->{PKCS7};
    $params{SIGNER}     = $self->{SIGNER};
    $self->{CHAIN} = $self->{TOKEN}->command({COMMAND => "pkcs7_get_chain", %params});
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
__END__

=head1 Name

OpenXPKI::Crypto::PKCS7

=head1 Description

This is an abstraction layer to handle PKCS#7 cryptographic
messages. Such messages can be S/MIME and several other stuff
like SCEP or normal encrypted/signed data. The object can also
be used to create such signatures or encrypted data portions.

=head1 Functions

=head2 new

The constructor only requires a minimal set of informations.
First it needs the cryptographic token (which is required).

Additionally you must specify a PKCS7 structure or some CONTENT.
If you want to verify or decrypt some data then you must support PKCS7.
If you want to sign or encrypt then you must support CONTENT.

=head2 sign

is used to sign some CONTENT which was specified during new. Nevertheless
you can specify some different CONTENT here too. Additionally the
following parameters are supported:

=over

=item * CERT (if you do not use the tokens key)

=item * KEY (if you do not use the tokens key)

=item * PASSWD (if you do not use the tokens key)

=item * ENC_ALG (used encryption algorithm - default is aes256)

=item * DETACH (detach data from signature -default is attached data)

=back

The signature will be returned a PEM-formatted PKCS#7.

=head2 verify

is used to verify a PKCS7 signature which was specified during new. Nevertheless
you can specify some different PKCS7 here too. Additionally the
following parameters are supported:

=over

=item * CONTENT (can be specified to check the integrity of the CONTENT)

=item * CHAIN (array with all trusted CA certificates (PEM))

=item * NO_VERIFY (only check the integrity but not the signer)

=back

The signer's PEM encoded certificate will be returned.

=head2 encrypt

is used to encrypt some CONTENT which was specified during new. Nevertheless
you can specify some different CONTENT here too. Additionally the
following parameters are supported:

=over

=item * CERT (if you do not use the tokens key for decryption)

=item * ENC_ALG (used encryption algorithm - default is aes256)

=back

The encrypted data is returned in PEM format.

=head2 decrypt

is used to decrypt a PKCS7 message which was specified during new. Nevertheless
you can specify some different PKCS7 here too. Additionally the
following parameters are supported:

=over

=item * CERT (if you do not use the tokens key)

=item * KEY (if you do not use the tokens key)

=item * PASSWD (if you do not use the tokens key)

=back

The decrypted data will be returned.

=head2 get_chain

is used to egt the certificate chain of a signature which was specified during new.
Nevertheless you can specify some different PKCS7 here too. 

The chain is cached and returned an ARRAY reference.

If you do not verify the signature before you use this function
then the signature is verified before the chain will be extracted.

=head2 get_signer

returns the signer of a signature. The functions verify or get_chain
must be used before you can use this function.

=head2 get_content

returns the content. This makes sense for encrypted PKCS#7 structures.

=head2 get_pkcs7

returns the PKCS#7 structure. This makes sense for later access to
newly created PKCS#7 structures.
