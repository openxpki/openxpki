# OpenXPKI::Server::Workflow::Activity::Tools:RetrieveItemFromPasswordsafe
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::RetrieveItemFromPasswordsafe;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::FileUtils;
use Crypt::CBC;
use MIME::Base64;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $ser = OpenXPKI::Serialization::Simple->new(
	{
	    SEPARATOR => '-',
	});

    my $keyentry = $self->param('contextkeyentry');
    my $valueentry = $self->param('contextvalueentry');
    my $safeprefix = $self->param('safeprefix') || '';
    my $aeskeyfile = $self->param('aeskeyfile');
    my $aeskey;
    my $iv;

    if (defined $aeskeyfile) {
	# read key
	$aeskey = OpenXPKI::FileUtils->read_file($aeskeyfile);

	chomp($aeskey);
	$aeskey =~ s{ [\s:.] }{}xgms;

	if ($aeskey !~ m{ \A [0-9a-fA-F]{64} \z }xms) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_RETRIEVEITEMINPASSWORDSAFE_INCORRECT_AES_KEY',
		params => {
		    aeskeyfile => $aeskeyfile,
		},
		);
	}
	$aeskey = pack('H*', $aeskey);

	$iv = Crypt::CBC->random_bytes(16);
    }


    my $key = $context->param($keyentry);
    ##! 64: 'keyentry: ' . $keyentry

    my $passwordsafe_id = $context->param('passwordsafe_workflow_id');
    if (! defined $passwordsafe_id) {
	$passwordsafe_id = $context->param('_passwordsafe_workflow_id');
    }
    ##! 64: 'passwordsafe_id: ' . $passwordsafe_id

    my $passwordsafe_workflow_title = 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE';

    # sanity checks
    if (! defined $keyentry) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_RETRIEVEITEMINPASSWORDSAFE_MISSING_KEYENTRY_DEFINITION',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }

    if (! defined $valueentry) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_RETRIEVEITEMINPASSWORDSAFE_MISSING_VALUEENTRY_DEFINITION',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }

    if (! defined $key) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_RETRIEVEITEMINPASSWORDSAFE_NO_KEY_FOUND_IN_CONTEXT',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }

    if (! defined $passwordsafe_id || ($passwordsafe_id !~ m{ \A \d+ \z }xms)) {
	OpenXPKI::Exception->throw(
	    message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_TOOLS_RETRIEVEITEMINPASSWORDSAFE_INVALID_PASSWORDSAFE_ID',
	    params => {
		contextkeyentry => $keyentry,
		contextvalueentry => $valueentry,
		safeprefix => $safeprefix,
		passwordsafe => $passwordsafe_id,
	    },
	    );
    }

    ##! 16: 'retrieving data from passwordsafe'
    my $passwordsafe_workflow = CTX('api')->execute_workflow_activity(
 	{
 	    ID => $passwordsafe_id,
 	    WORKFLOW => $passwordsafe_workflow_title,
 	    ACTIVITY => 'retrieve_password',
 	    PARAMS => {
		_id => $safeprefix . $key,
 	    }
 	});

    my $passwords = $passwordsafe_workflow->{WORKFLOW}->{CONTEXT}->{'_passwords'};
    my $serialized_data = $passwords->{$safeprefix . $key};
    my $data = $ser->deserialize($serialized_data);
    my $value = $data->{Password};
    
    # optional AES encryption of retrieved password
    if (defined $aeskey) {
	my $cipher = Crypt::CBC->new(
	    -cipher => 'Crypt::OpenSSL::AES',
	    -key    => $aeskey,
	    -iv     => $iv,
	    -literal_key => 1,
	    -header => 'none',
	    );
	my $encrypted_value = $cipher->encrypt($value . "\000");
	$value = encode_base64($iv . $encrypted_value, '');
    }
    
    $context->param($valueentry => $value);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RetrieveItemFromPasswordsafe

=head1 Description

Writes a context entry to a PasswordSafe.

Configuration (activity definition):
contextkeyentry           Specifies which context entry to use as password
                          safe key
contextvalueentry         Specifies which context entry to use as password
                          safe value
safeprefix                String to prepend to the password safe key entry
aeskeyfile                path to file containing AES256 key (32 hex bytes, no
                          whitespace or separator characters)

Runtime variables (from context):
passwordsafe_workflow_id  Workflow ID of a usable passwordsafe

Retrieves an encrypted entry determined by contextkeyentry from the 
specified passwordsafe workflow by calling retrieve_password on this 
workflow instance.

The value is returned in the specified context value entry.

If aeskeyfile is specified, the file contents are read and interpreted
as a hex-encoded AES key (no whitespace, no additional charactes except
hex digits).
The password that was retrieved from the password safe is then encrypted
using the specified AES key, using a random IV (see below).




Encryption scheme

The algorithm used is AES-256 with cipher block chaining (CBC) 
and PKCS#5-padding. The encrypted secret is preceded by a 16 byte 
block containing the initialization vector (IV) for the first round 
of AES encryption. The file pin must be encrypted including the 
string terminator. 

Example 

String to encrypt (27 bytes including terminator): 

“ThisIsAnUnencryptedFilePIN\0” 

Hex representation, PKCS#5- padded: 
0x54, 0x68, 0x69, 0x73, 0x49, 0x73, 0x41, 0x6E, 
0x55, 0x6E, 0x65, 0x6E, 0x63, 0x72, 0x79, 0x70, 
0x74, 0x65, 0x64, 0x46, 0x69, 0x6C, 0x65, 0x50, 
0x49, 0x4E, 0x00, 0x05, 0x05, 0x05, 0x05, 0x05 

AES-256 key (32 bytes): 
cafecafecafecafecafecafecafecafecafecafecafecafecafecafecafecafe

Initialization Vector IV (16 bytes): 
00112233445566778899aabbccddeeff

Encrypted FilePIN (32 bytes): 
0x26, 0x62, 0x73, 0xC3, 0x26, 0x1C, 0xAB, 0xDD, 
0x73, 0x9C, 0x4B, 0x64, 0x5B, 0x7D, 0x93, 0xB4, 
0xD5, 0xFC, 0xFB, 0xDD, 0xE7, 0xB4, 0xFC, 0xB7, 
0x35, 0x7A, 0x5A, 0x3A, 0x4C, 0x58, 0xFF, 0x6C 

Base64-encoded string of IV and encrypted FilePIN: 
ABEiM0RVZneImaq7zN3u/yZic8MmHKvdc5xLZFt9k7TV/Pvd57T8tzV6WjpMWP9s

