# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::Key::Generate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use Log::Log4perl       qw( get_logger );

# use Smart::Comments;

use OpenXPKI::Exception;
use OpenXPKI::Crypto::TokenManager;  


sub execute {
    my $self = shift;
    my $workflow = shift;

    my $_public = [ 'context', 'config', 'default' ];

    $self->SUPER::execute($workflow,
			  {
			      ACTIVITYCLASS => 'PUBLIC',
			      PARAMS => {
				  keytype => {
				      accept_from => $_public,
				      default => 'RSA',
				  },
				  curvename => {
				      accept_from => $_public,
				      default => 'prime192v1',
				  },
				  keylength => {
				      accept_from => $_public,
				      default => 1024,
				  },
				  keyencryptionalgorithm => {
				      accept_from => $_public,
				      default => 'aes256',
				  },
				  passphrase => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  _token => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
			      },
			  });
    
    my $context = $workflow->context();
    my $log = get_logger(); 

    # sanity checks
    if ($self->param('keytype') !~ m{\A (?:RSA|DSA|EC) \z}xms ) {
    	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_KEY_GENERATE_INCORRECT_ALGORITHM",
	    params  => { 
		'KEYTYPE' => $self->param('keytype'),
	    });
    }


    my $token = $self->param('_token');


    my $key = $token->command("create_key",
			      TYPE       => $self->param('keytype'),
			      KEY_LENGTH => $self->param('keylength'),
			      CURVE_NAME => $self->param('curvename'),
			      ENC_ALG    => $self->param('keyencryptionalgorithm'),
			      PASSWD     => $self->param('passphrase'),
	);

    # export
    $context->param(key => $key);


    $workflow->add_history(
        Workflow::History->new({
            action      => 'Generate key pair',
            description => sprintf( "Generated %d bit %s public key pair",
                                    $self->param('keylength'), 
				    $self->param('keytype') ),
            user        => $self->param('creator'),
			       })
	);
}


1;

=head1 Description

Implements the 'key generation' workflow activity.


=head2 Context parameters

Expects the following context parameters:

=over 12

=item _token

Cryptographic token to use for key generation. The default token is
sufficient for this purpose.

=item keytype

Public key algorithm to use. Acceptable values: 'RSA', 'DSA', 'EC'

=item keylength

Key length in bit.

=item keyencryptionalgorithm

Key encryption algorithm to use (defaults to 'AES256').

=item passphrase

Passphrase to protect the private key.

=item curvename

Elliptic curve name to use.

=back

After completion the following context parameters will be set:

=over 12

=item key
    
PEM encoded public key pair (encrypted with 'passphrase' if 
'keyencryptionalgorithm' was not explicitly cleared)

=back

=head1 Functions

=head2 execute

Executes the activity.

