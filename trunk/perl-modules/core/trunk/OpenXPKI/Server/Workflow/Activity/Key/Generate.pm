# OpenXPKI Workflow Activity
# Copyright (c) 2005 Martin Bartosch
# $Revision: 80 $

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

    $self->setparams($workflow, 
		     {
			 keytype => {
			     default => 'RSA',
			 },
			 curvename => {
			 },
			 keylength => {
			     default => 1024,
			 },
			 keyencryptionalgorithm => {
			     default => 'aes256',
			 },
			 keypass => {
			 },
			 token => {
			     required => 1,
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


    my $token = $self->param('token');

    # encryption algorithm but no pass phrase specified
    if (! $self->param('keypass')
	&& $self->param('keyencryptionalgorithm')) {
	
	# generate a random pass phrase
	$self->param('keypass',
		     $token->command ("create_random", RANDOM_LENGTH => 16));

	# export
	$context->param(keypass => $self->param('keypass'));
    }
    

    my $key = $token->command("create_key",
			      TYPE       => $self->param('keytype'),
			      KEY_LENGTH => $self->param('keylength'),
			      CURVE_NAME => $self->param('curvename'),
			      ENC_ALG    => $self->param('keyencryptionalgorithm'),
			      PASSWD     => $self->param('keypass'),
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

=item token

Cryptographic token to use for key generation. The default token is
sufficient for this purpose.

=item keytype

Public key algorithm to use. Acceptable values: 'RSA', 'DSA', 'EC'

=item keylength

Key length in bit.

=item keyencryptionalgorithm

Key encryption algorithm to use (defaults to 'AES256').

=item keypass

If specified (and keyencryptionalgorithm is not empty) uses the specified
passphrase to protect the private key.
If empty the activity generates a 16 character random pass phrase and
uses this instead. This pass phrase is then exported via the context.

=item curvename

Elliptic curve name to use.

=back

After completion the following context parameters will be set:

=over 12

=item key
    
PEM encoded public key pair (enrcypted with 'keypass' if 
'keyencryptionalgorithm' was not explicitly cleared)

=item keypass

Will be set to a random pass phrase if it was not set in 
context before.

=back

=head1 Functions

=head2 execute

Executes the activity.

