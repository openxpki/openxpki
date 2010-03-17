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
use Digest::SHA1 qw( sha1_base64 );

# use Smart::Comments;

{
    # using a block here protects private instance data from access
    # from the outside


    # If you wish to specify an :init_arg with Class::Std that is optional, you need to specify
    # a :default() value. Unfortunately Class::Std checks if the value is 'defined', which isn't
    # true for a literal undef. In this case Class::Std bails out with an error because no
    # argument was passed for the 'mandatory' :init_arg.
    # Work around this problem by specifying a non-undef default value. The value 'unspecified'
    # is an invalid key and causes an exception later if something goes wrong.
    #
    # Sigh.
    my %session_key   : ATTR( :init_arg<KEY> :default( 'unspecified' ) );
    my %session_iv    : ATTR( :init_arg<IV>  :default( 'unspecified' ) );
    my %token         : ATTR( :init_arg<TOKEN> );

    my %algorithm     : ATTR( :init_arg<ALGORITHM> :get<algorithm> :default('aes-256-cbc') );
    my %encoding      : ATTR( :init_arg<ENCODING> :default('base64-oneline') );

    my %exportable    : ATTR( :init_arg<EXPORTABLE> :default(0) );

    sub START {
	my ($self, $ident, $arg_ref) = @_;

	if ($exportable{$ident} !~ m{ \A -?\d+ \z }xms) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_INVALID_EXPORTABLE_SETTING");
        }
	if ($exportable{$ident} < -1) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_INVALID_EXPORTABLE_SETTING");
	}

	if ($session_key{$ident} eq 'unspecified') {
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
	} else {
	    # specifying key without iv is at least stupid...
	    if (! defined $session_iv{$ident}) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_USER_SPECIFIED_KEY_WITHOUT_IV");
	    }
	}

	if ($session_iv{$ident} eq 'unspecified') {
	    if (! exists $token{$ident}) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_MISSING_TOKEN");
	    }

	    my $iv = $token{$ident}->command(
		{
		    COMMAND => 'create_random',
		    RANDOM_LENGTH => 16,
		    INCLUDE_PADDING => 1,
		});
	    
	    # convert base64 to binary and get hex representation of this data
	    $session_iv{$ident} = uc(unpack('H*', 
					    MIME::Base64::decode_base64($iv)));
	}

	if (! length($session_key{$ident}) || ! length ($session_iv{$ident})) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_INITIALIZATION_ERROR");
	}
	
	if ($session_key{$ident} !~ m{ \A [0-9A-F]+ \z }xms) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_INVALID_KEY");
	}

	if ($session_iv{$ident} !~ m{ \A [0-9A-F]+ \z }xms) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_INVALID_IV");
	}

	if ($algorithm{$ident} ne 'aes-256-cbc') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_UNSUPPORTED_ALGORITHM");
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
		    $self->get_key_id(),
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
	if ($self->get_key_id() eq $creator_ident) {
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
	if ($self->get_key_id() ne $creator_ident) {
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


    sub export_key {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	# check if we are allowed to export the key
	if ($exportable{$ident} == 0) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_EXPORT_KEY_DENIED",
		params => {
		});
	}
	
	if ($exportable{$ident} > 0) {
	    # decrement export counter
	    $exportable{$ident}--;
	}

	return {
	    KEY => $session_key{$ident},
	    IV  => $session_iv{$ident},
	    ALGORITHM => $algorithm{$ident},
	}
    }


    sub lock_vault {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	$exportable{$ident} = 0;
    }

    sub get_key_id {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	my %args;
	if ($arg->{LONG}) {
	    $args{LONG} = 1,
	}

	return $self->_compute_key_id(
	    {
		KEY => $session_key{$ident},
		IV  => $session_iv{$ident},
		ALGORITHM => $algorithm{$ident},
		%args,
	    });
    }

    # expects named arguments KEY and IV. returns truncated base64 encoded SHA1 hash of concatenated KEY and IV.
    sub _compute_key_id : PRIVATE {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	if (! ((defined $arg->{IV}) && (defined $arg->{KEY}) && (defined $arg->{ALGORITHM}))) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_COMPUTE_KEY_ID_MISSING_PARAMETERS");
	}
	
	my $digest = sha1_base64(join(':', $arg->{ALGORITHM}, $arg->{IV}, $arg->{KEY}));

	if ($arg->{LONG}) {
	    return $digest;
	} else {
	    return (substr($digest, 0, 8));
	}
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

=head3 Specifying keys
It is possible to specify a symmetric key and IV to use by passing
KEY and IV values to the constructor. KEY and IV must be specified
using upper case hexadecimal digits (no whitespace allowed). The
caller must make sure that KEY and IV do make sense (are long enough
etc.). Specifying a KEY without IV yields an exception.

=head3 Exporting keys
It is also possible to mark the internally used key and iv as
exportable. This can be forced by explicity setting the EXPORTABLE
variable. EXPORTABLE is interpreted as an integer
and decremented every time key and iv are exported. Exporting the values
is only possible as long as the counter is greater than zero. Setting
EXPORTABLE to -1 allows unlimited key exports. Setting EXPORTABLE
to 0 in the constructor is identical to not allowing export at all.
The constructor throws an exception if EXPORTABLE is not an integer
greater or equal -1.

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

=head2 export_key()

Exports the internally used symmetric key and IV. Exporting is only possible
if the object was created with the EXPORTABLE option. Every call to
export_key() decrements the internal export counter; a key export is only
possible as long as the maximum export counter has not been exceeded.
(See constructor description.)
If exporting the key is not explicitly allowed the method throws an
exception.
The returned key is returned in a hash reference with KEY, IV and
ALGORITHM keys. The values for KEY and IV are hexadecimal (uppercase) 
numbers specifying the key and initialization vector.

=head2 lock_vault()

If the vault was created with the EXPORTABLE option, it allows to export
the internally used private key via export_key(). Once the lock_vault()
method is called, the export option is immediately shut down (max
export counter is set to 0) and it is no longer possible to export the
internally used key.

=head2 get_key_id()

Returns a key id which may be used to identify the used symmetric key. The
returned key id is a truncated base64 encoded SHA1 hash (8 characters) of 
key and iv. Collisions may occur.

If the named argument LONG is set, the returned key id is the full base64
encoded SHA1 hash of the key.

=head2 Advanced usage

Provide externally generated key and IV:

  use OpenXPKI::Crypto::VolatileVault;
  my $token = ...
  my $key = 'DEADBEEFCAFEBABE';
  my $iv = '012345678';
  my $vault = OpenXPKI::Crypto::VolatileVault->new(
    {
        TOKEN => $token,
        KEY => $key,
        IV => $iv,
    });
  my $encrypted = $vault->encrypt('supersecretdata');

  ...

  my $tmp = $vault->decrypt($encrypted);  



Let VolatileVault pick its own random key but allow exporting the key.

  use OpenXPKI::Crypto::VolatileVault;
  my $token = ...
  my $vault = OpenXPKI::Crypto::VolatileVault->new(
    {
        TOKEN => $token,
        EXPORTABLE => 2,
    });
  my $encrypted = $vault->encrypt('supersecretdata');

  ...

  my $tmp = $vault->decrypt($encrypted);  

  my $key;
  $key = $vault->export_key(); # works
  $key = $vault->export_key(); # works
  $key = $vault->export_key(); # fails (export was only allowed 2 times above)
 
