# OpenXPKI::Server::Workflow::Persister::Null

package OpenXPKI::Server::Workflow::Persister::Null;

use strict;
use base qw( Workflow::Persister );
use utf8;
use English;

use OpenXPKI::Debug;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

sub init {
    my $self = shift;
    my $params = shift;

    $self->SUPER::init( $params );

    return; # no useful return value
}

sub create_workflow {
    my $self = shift;
    my $workflow = shift;
    ##! 1: "create volatile workflow"

    CTX('log')->workflow()->info("Created volatile workflow for type ".$workflow->type());


    return 0;
}

sub update_workflow {
    my $self = shift;
    my $workflow = shift;

    ##! 1: "update_workflow"
    return 1;
}

sub fetch_workflow {

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_FETCH_WORKFLOW_NOT_POSSBILE_WITH_NULL_PERSISTER',
    );

}


sub create_history {
    my $self = shift;
    my $workflow = shift;
    return ();
}


sub fetch_history {

    return ();
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Persister::Null

=head1 Description

B<THIS IS AN EXPERIMENTAL FEATURE>

This class provides a persister for "throw away" workflows. Those are not
persisted and therefore are only useable for "one shot" operations.
Be aware that you loose all workflow related data once the workflows ends!


