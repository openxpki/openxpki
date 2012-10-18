# OpenXPKI::Server::Workflow::Condition::WFArray
# Written by Scott Hardin for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::WFArray;

use strict;
use warnings;
use base qw( Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Exception;
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Debug;
use English;

my @parameters = qw(
    array_name
    condition
);

__PACKAGE__->mk_accessors(@parameters);

sub _init {
    my ( $self, $params ) = @_;

    # propagate workflow condition parametrisation to our object
    foreach my $arg (@parameters) {
        if ( defined $params->{$arg} ) {
            $self->$arg( $params->{$arg} );
        }
    }
    if ( !( defined $self->array_name() ) ) {
        configuration_error
            "Missing parameter 'array_name' in " .
            "declaration of condition " . $self->name();
    }
}


sub evaluate {
    my ( $self, $wf ) = @_;
    my $context = $wf->context();


    my $array = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	{ 
	    workflow => $wf,
	    context_key => $self->array_name(),
	} );

    if ($self->condition() eq 'is_empty') {
	if ($array->count() == 0) {
	    return 1;
	}
	condition_error
	    'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WFARRAY_ARRAY_NOT_EMPTY';
    } else {
        configuration_error
            "Invalid condition " . $self->condition() . " in " .
            "declaration of condition " . $self->name();
    }
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WFArray

=head1 SYNOPSIS

  <condition 
     name="queue_is_empty" 
     class="OpenXPKI::Server::Workflow::Condition::WFArray">
    <param name="array_name" value="cert_queue"/>
    <param name="condition" value="is_empty"/>
  </condition>

=head1 DESCRIPTION

Allows for checks of the contents of an array stored as a workflow
context parameter.

=head1 PARAMETERS

=head2 array_name

The name of the workflow context parameter containing the array to be used

=head2 condition

The following conditions are supported:

=over 8

=item is_empty

Condition is true if the array is either non-existent or is empty.

=back


