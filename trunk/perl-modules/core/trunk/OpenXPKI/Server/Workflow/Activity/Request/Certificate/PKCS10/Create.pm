# OpenXPKI::Server::Workflow::Activity::Request::Certificate::PKCS10::Create
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::Request::Certificate::PKCS10::Create;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use Log::Log4perl       qw( get_logger );

use OpenXPKI::Server::Context qw( CTX );

# use Smart::Comments;


sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->SUPER::execute($workflow,
			  {
			      ACTIVITYCLASS => 'PUBLIC',
			      PARAMS => {
				  key => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  passphrase => {
				      accept_from => [ 'context' ],
				  },
				  subject => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
			      },
			  });    


    my $context = $workflow->context();
    my $log = get_logger(); 

    my $token = $self->{TOKEN}->{DEFAULT};

    ## create CSR
    my $csr = $token->command ({COMMAND => "create_pkcs10",
			        KEY     => $self->param('key'),
			        PASSWD  => $self->param('passphrase'),
			        SUBJECT => $self->param('subject')});
    

    ### Creating PKCS10 request...
    # export
    $context->param(pkcs10request => $csr);

    $workflow->add_history(
        Workflow::History->new({
            action      => 'Create PKCS#10 request',
            description => sprintf( "Created PKCS#10 request"
		),
            user        => $self->param('creator'),
			       })
	);
    
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Request::Certificate::PKCS10::Create

=head1 Description

Implements the 'PKCS#10 request creation' workflow action.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item creator

User id of creator

=item key

Public key pair to use for creating the request.

=item passphrase

Passphrase protecting the private key.

=item subject

Request subject.

=back

FIXME: This activity is the entry point as seen from the web interface. 
We should list and require all parameters that have to be queried from
the user.

After completion the following context parameters will be set:

=over 12

=item pkcs10request

PEM encoded PKCS#10 certificate request.

=back

=head1 Functions

=head2 execute

Executes the action.
