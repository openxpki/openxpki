## OpenXPKI::Crypto::VolatileVault.pm 
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

package OpenXPKI::Crypto::VolatileVault;

use Class::Std;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;

use MIME::Base64;
use Crypt::CBC;

# use Smart::Comments;

{
    # using a block here protects private instance data from access
    # from the outside
    my %session_key   : ATTR;
    my %session_iv    : ATTR;
    my %token         : ATTR( :init_arg<TOKEN> );

    my %algorithm     : ATTR( :init_arg<ALGORITHM> :get<algorithm> :default('aes-256-cbc') );
    my %encoding      : ATTR( :init_arg<ENCODING> :default('base64-oneline') );

    sub START {
	my ($self, $ident, $arg_ref) = @_;

	if (! exists $token{$ident}) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_MISSING_TOKEN");
	}

	
	my $key = $token{$ident}->command(
	    {
		COMMAND => 'create_random',
		RANDOM_LENGTH => 32,
		INCLUDE_PADDING => 1,
	    });

	# convert base64 to binary and get hex representation of this data
	$session_key{$ident} = uc(unpack('H*', 
					 MIME::Base64::decode_base64($key)));

	my $iv = $token{$ident}->command(
	    {
		COMMAND => 'create_random',
		RANDOM_LENGTH => 16,
		INCLUDE_PADDING => 1,
	    });

	# convert base64 to binary and get hex representation of this data
	$session_iv{$ident} = uc(unpack('H*', 
					MIME::Base64::decode_base64($iv)));

	if (! length($session_key{$ident}) || ! length ($session_iv{$ident})) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_INITIALIZATION_ERROR");
	}
	
    }


    sub encrypt {
	my $self = shift;
	my $ident = ident $self;
	my $args = shift;

	my $data;
	my $encoding = $encoding{$ident};

	if (defined $args && (ref $args eq 'HASH')) {
	    $data     = $args->{DATA};
	    $encoding = $args->{ENCODING};
	} elsif (defined $args && (ref $args eq '')) {
	    $data     = $args;
	}
	
	if (! defined $data || ! defined $encoding) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_ENCRYPT_INVALID_PARAMETER");
	}
	
    my $cipher = Crypt::CBC->new(
        -cipher => 'Crypt::OpenSSL::AES',
        -key    => pack('H*', $session_key{$ident}),
        -iv     => pack('H*', $session_iv{$ident}),
        -literal_key => 1,
        -header => 'none',
    );
    my $encrypted = $cipher->encrypt($data);
	my $blob;

	if ($encoding eq 'base64') {
	    $blob = MIME::Base64::encode_base64($encrypted);
	}

	if ($encoding eq 'base64-oneline') {
	    $blob = MIME::Base64::encode_base64($encrypted, '');
	}

	if ($encoding eq 'raw') {	 
	    $blob = $encrypted;
	}

	if (! defined $blob) {	 
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_ENCRYPT_INVALID_ENCODING",
		params => {
		    ENCODING => $encoding,
		});
	}

	return join(';', 
		    $ident, 
		    $encoding, 
		    $blob);
    }

    sub can_decrypt {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

        if (! defined $arg || $arg eq '') {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_CAN_DECRYPT_MISSING_ARGUMENT',
            );
        }
	my ($creator_ident, $encoding, $encrypted_data) = 
	    ($arg =~ m{ (.*?) ; ([\w\-]+) ; (.*) }xms);

	if (! defined $encrypted_data) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_DECRYPT_INVALID_ENCRYPTED_DATA");
	}

	# check if we created this cookie
	if ($ident eq $creator_ident) {
	    return 1;
	}
	return;
    }

    sub decrypt {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	my ($creator_ident, $encoding, $encrypted_data) = 
	    ($arg =~ m{ (.*?) ; ([\w\-]+) ; (.*) }xms);

	if (! defined $encrypted_data) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_DECRYPT_INVALID_ENCRYPTED_DATA");
	}

	# check if we created this cookie
	if ($ident ne $creator_ident) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_DECRYPT_INVALID_VAULT_INSTANCE");
	}

	if (($encoding eq 'base64') || ($encoding eq 'base64-oneline')) {
	    $encrypted_data = MIME::Base64::decode_base64($encrypted_data);
	}

    my $cipher = Crypt::CBC->new(
        -cipher => 'Crypt::OpenSSL::AES',
        -key    => pack('H*', $session_key{$ident}),
        -iv     => pack('H*', $session_iv{$ident}),
        -literal_key => 1,
        -header => 'none',
    );
	return $cipher->decrypt($encrypted_data);
    }    
    
	

}

1;
__END__

=head1 Name

OpenXPKI::Crypto::VolatileVault

=head1 Description

This class implements a volatile storage for holding sensitive information
during the runtime of a program.

  use OpenXPKI::Crypto::VolatileVault;
  my $token = ...
  my $vault = OpenXPKI::Crypto::VolatileVault->new(
    {
        TOKEN => $token,
    });
  my $encrypted = $vault->encrypt('supersecretdata');

  ...

  my $tmp = $vault->decrypt($encrypted);  

The constructor will generate a random symmetric key and store it in an
instance variable. 
The class uses inside-out objects via Class::Std to make sure that 
the secret key is strictly internal to the instance and not
accessible from the outside.

Encrypted data includes an instance ID that allows a particular instance
to determine if it has created a given piece of encrypted data, hence
it can check if it is capable of decrypting the data without actually
trying to do so.

=head2 new()

Creates a new vault object instance. Requires an initialized
default token to be passed via the named parameter TOKEN.

Accepts a named parameter ENCODING which sets the instance's default
encoding for the encrypted data string. ENCODING may be one of
'raw' (binary), 'base64' (Base64 with newlines) and 'base64-oneline'
(Base64 without any whitespace or newlines). Default is 'base64-oneline'.

=head2 encrypt()

If the first argument to encrypt() is a hash reference the method 
accepts the named arguments 'DATA' and 'ENCODING'.

DATA contains the scalar data to encrypt.

ENCODING defaults to the default encoding for the instance and may be 
one of 'base64' (base64 encoding), 'base64-oneline' (base64 encoding 
on one single line without any whitespace or line breaks) or 
'raw' (binary data).

If the first argument to encrypt() is a scalar instead of a hash reference
it is assumed to contain the data to encrypt (just like a DATA named 
argument).

During the lifetime of the instance the caller may call the encrypt() 
method in order to protect sensitive data. The method encrypts the
specified data with the secret key and returns the encrypted value.
This encrypted data may now be stored in insecure places because the
decryption is only possible via the same class instance that encrypted
it in the first plase.

WARNING: after destruction of the class instance decryption of data
encrypted by this instance is impossible.

The method returns the enrypted data that may be stored in unsafe storage
and may be passed to decrypt() of the same instance in order to access
the stored data.

=head2 decrypt()

Accepts a scalar argument containing the encrypted data to encrypt and
returns the original clear text.
This only works if the encrypted data was created by the same object
instance of this class.

=head2 can_decrypt()

Accepts one scalar attribute and checks if the class instance would
be able to decrypt the data. Returns true if this instance can decrypt
it.

There is a small probability that the method returns a false positive
(if a previous instance used the same instance ID).

The method throws an exception if the data to be decrypted is not 
recognized to be a valid VolatileVault data block.
