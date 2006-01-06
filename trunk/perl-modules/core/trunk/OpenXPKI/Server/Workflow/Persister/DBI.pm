# OpenXPKI Workflow Persister
# Copyright (c) 2005 Martin Bartosch
# $Revision: 80 $

package OpenXPKI::Server::Workflow::Persister::DBI;

use strict;
use base qw( Workflow::Persister );

use OpenXPKI::Exception;

sub init {

}

sub create_workflow {
    my $self = shift;
    my $workflow = shift;

    my $workflow_id = 'dummy';

    return $workflow_id;
}

sub update_workflow {

}

sub fetch_workflow {
    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_NOT_IMPLEMENTED",
	params  => {
	    METHOD    => 'fetch_workflow',
	},
	);
}

sub create_history {

}


sub fetch_history {
    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_NOT_IMPLEMENTED",
	params  => {
	    METHOD    => 'fetch_history',
	},
	);
}


##

sub assign_generators {
    my $self = shift;
    my $params = shift;

    $self->SUPER::assign_generators( $params );
    return if ( $self->workflow_id_generator and
                $self->history_id_generator );

    
    

}



1;

=head1 Description

Implements the OpenXPKI Workflow persister using the OpenXPKI DBI 
infrastructure. We do not subclass the Workflow::Persister::DBI here
because we'd like to have a single SQL abstraction layer in the
main DBI module.

=head1 Functions

