# OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::FetchPUK
# Written by Scott Hardin for the OpenXPKI project 2005
#
# Based on OpenXPKI::Server::Workflow::Activity::Skeleton,
# written by Martin Bartosch for the OpenXPKI project 2005
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::FetchPUK;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
	##! 1: 'start'
    my $self = shift;
    my $workflow = shift;
	my $context = $workflow->context();

	##! 1: 'stubbing execute()'
	return $self;


    $self->SUPER::execute($workflow,
			  {
			      # CHOOSE one of the following:
			      # CA: CA operation (default)
			      # RA: RA operation
			      # PUBLIC: publicly available operation
			      #ACTIVITYCLASS => 'CA',
			      PARAMS => {
#				  # accept_from values (first match wins):
#				  # 'context': accept workflow context values
#				  # 'config':  accept workflow config values
#				  # 'default': accept defaults in source code
# 				  _myvolatile => {
#				      # accept_from => [ 'config', 'default' ],
# 				      # default => '',
# 				      # required => 1,
# 				  },
# 				  mypersistent => {
#				      # accept_from => [ 'context', 'config', 'default' ],
# 				      # default => '',
# 				      # required => 1,
# 				  },
			      },
			  });    


    # you may wish to use these shortcuts
#     my $context      = $workflow->context();
#     my $activity     = $self->{ACTIVITY};
#     my $pki_realm    = $self->{PKI_REALM};
#     my $session      = $self->{SESSION};
#     my $defaulttoken = $self->{TOKEN_DEFAULT};


    $workflow->add_history(
        Workflow::History->new({
            action      => 'My action description',
            description => sprintf( "My log message"
		),
            user        => $self->param('creator'),
			       })
	);
    
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Skeleton

=head1 Description

Implements the FIXME workflow action.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item ...

Description...

=item ...

Description...

=back

After completion the following context parameters will be set:

=over 12

=item ...

Description...

=back

=head1 Functions

=head2 execute

Executes the action.
