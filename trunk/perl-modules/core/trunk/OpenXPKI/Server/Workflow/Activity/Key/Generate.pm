# OpenXPKI::Server::Workflow::Activity::Key::Generate
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::Key::Generate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use Log::Log4perl       qw( get_logger );

# use Smart::Comments;

use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );


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


    my $session = CTX('session');
    if (! defined $session) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_KEY_GENERATE_INVALID_SESSION",
            );
    }

    my $pki_realm = $session->get_pki_realm();
    if (! defined $pki_realm) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_KEY_GENERATE_PKI_REALM_UNDEFINED",
            );
    }
    
    my $token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    if (! defined $token) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_KEY_GENERATE_TOKEN_UNAVAILABLE",
            );
    }

    my %params = ();
    if ($self->param('keytype') eq "RSA" or
        $self->param('keytype') eq "DSA")
    {
        $params{KEY_LENGTH} = $self->param('keylength');
        $params{ENC_ALG}    = $self->param('keyencryptionalgorithm');
    }
    elsif ($self->param('keytype') eq "EC")
    {
        $params{CURVE_NAME} = $self->param('curvename');
        $params{ENC_ALG}    = $self->param('keyencryptionalgorithm');
    }
    else
    {
    	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_KEY_GENERATE_INCORRECT_ALGORITHM",
	    params  => { 
		'KEYTYPE' => $self->param('keytype'),
	    });
    }

    my $key = $token->command({COMMAND    => "create_key",
			       TYPE       => $self->param('keytype'),
			       PASSWD     => $self->param('passphrase'),
                               PARAMETERS => {%params}
                              });

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
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Key::Generate

=head1 Description

Implements the 'key generation' workflow activity.


=head2 Context parameters

Expects the following context parameters:

=over 12

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

