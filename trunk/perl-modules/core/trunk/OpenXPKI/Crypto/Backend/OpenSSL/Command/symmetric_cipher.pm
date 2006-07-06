## OpenXPKI::Crypto::Backend::OpenSSL::Command::symmetric_encrypt
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision: 320 $

package OpenXPKI::Crypto::Backend::OpenSSL::Command::symmetric_cipher;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

use strict;
use warnings;
# use Smart::Comments;

sub get_command
{
    my $self = shift;
    
    if (! defined $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_SYMMETRIC_CIPHER_MISSING_DATA");
    }

    if (! defined $self->{MODE}
	|| (($self->{MODE} ne 'ENCRYPT') && $self->{MODE} ne 'DECRYPT'))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_SYMMETRIC_CIPHER_INCORRECT_MODE");
    }
    
    $self->{ENC_ALG}  = "aes-256-cbc" if (! exists $self->{ENC_ALG});
    
    my @key = ();
    
    if (exists $self->{PASSWD}) {
	@key = ('-pass', 
		'env:pwd');
	$self->set_env ("pwd" => $self->{PASSWD});		
    }
    
    if (exists $self->{KEY} && exists $self->{IV}) {
	if (scalar @key) {
	    OpenXPKI::Exception->throw(
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_SYMMETRIC_CIPHER_MUTUAL_EXCLUSIVE_PARAMETERS",
		);
	}
	
	my $key = $self->{KEY};
	my $iv  = $self->{IV};
	if ($key !~ m{ \A [0-9A-F]{2,64} \z }xms) {
	    OpenXPKI::Exception->throw(
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_SYMMETRIC_CIPHER_ILLEGAL_KEY",
		);
	}
	if ($iv !~ m{ \A [0-9A-F]{0,32} \z }xms) {
	    OpenXPKI::Exception->throw(
		message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_SYMMETRIC_CIPHER_ILLEGAL_IV",
		);
	}
	
	@key = ('-K',  $key,
		'-iv', $iv,
	    );
    }
    if (! scalar @key) {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_SYMMETRIC_CIPHER_MISSING_KEY_SPEC"
	    );
    }
    
    ## build the command
    my @cmd = ('enc',
	       '-' . $self->{ENC_ALG},
	       @key,
	);

    if ($self->{MODE} eq 'ENCRYPT') {
	$self->get_tmpfile('OUT');

	push @cmd, '-e';
	push @cmd, '-out', $self->{OUTFILE};

	return {
	    COMMAND => [
		join(' ', @cmd),
		],
	    PARAMS  => [
		{
		    TYPE  => 'STDIN',
		    DATA  => $self->{DATA},
		}
	    ],
	};
    } else {
	$self->get_tmpfile('IN');
	$self->write_file(FILENAME => $self->{INFILE},
			  CONTENT  => $self->{DATA},
			  FORCE    => 1);

	push @cmd, '-d';
	push @cmd, '-in', $self->{INFILE};

	return {
	    COMMAND => [ 
		join(' ', @cmd) 
		],
	    PARAMS  => [ 
		{
		    TYPE  => 'STDOUT',
		}
	    ],
	}
    }
}

sub hide_output
{
    return 1;
}

## please notice that key_usage means usage of the engine's key
sub key_usage
{
    my $self = shift;
    return 1;
}

sub get_result
{
    my $self = shift;
    my $result = shift;

    if (exists $self->{OUTFILE}) {
	return $self->read_file($self->{OUTFILE});
    } else {
	return $result;
    }
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::symmetric_cipher

Allows to symmetrically encrypt/decrypt arbitrary binary data. The 
implementation uses STDIN/STDOUT for the unencrypted end of the data
to process in order to make sure that no secret data is written to disk.

=head1 Functions

=head2 get_command

=over

=item * DATA

Data to encrypt or decrypt (mandatory).

=item * ENC_ALG (optional)

Encryption algorithm to use. May be one of the following:

aes-128-cbc
aes-128-cfb
aes-128-cfb1
aes-128-cfb8
aes-128-ecb
aes-128-ofb
aes-192-cbc
aes-192-cfb
aes-192-cfb1
aes-192-cfb8
aes-192-ecb
aes-192-ofb
aes-256-cbc
aes-256-cfb
aes-256-cfb1
aes-256-cfb8
aes-256-ecb
aes-256-ofb
aes128
aes192
aes256
des-ede3
des-ede3-cbc
des-ede3-cfb
des-ede3-ofb
des3

=item * MODE (mandatory)

May be either 'ENCRYPT' or 'DECRYPT'.

=item * PASSWD (optional)

Passphrase to use for encryption/decryption. Mutually exclusive with
KEY/IV.

=item * KEY (optional)

Hexadecimal string ([0-9A-F]+) specifying the symmetric key to use.

=item * IV (optional)

Hexadecimal string ([0-9A-F]+) specifying the initialization vector to use.

=back

=head2 hide_output

returns true

=head2 get_result

returns the encrypted/decrypted data
