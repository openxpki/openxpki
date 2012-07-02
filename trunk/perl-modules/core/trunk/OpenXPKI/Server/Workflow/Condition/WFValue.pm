# OpenXPKI::Server::Workflow::Condition::WFValue
## Written 2011 by Oliver Welter <openxpki@oliwel.de>
## for the OpenXPKI project
## (C) Copyright 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::WFValue;

use strict;
use warnings;
use base qw( Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Exception;
use OpenXPKI::Server::Workflow::WFObject::WFValue;
use OpenXPKI::Debug;
use English;

my @parameters = qw(
    param_name
    param_value
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
    if ( !( defined $self->param_name() ) ) {
        configuration_error
            "Missing parameter 'param_name' in " .
            "declaration of condition " . $self->name();
    }
}


sub evaluate {
    my ( $self, $wf ) = @_;
    my $context = $wf->context();
 
 	my $current_value = $context->param( $self->param_name() );
 
 	my $expected_value = $self->param_value();
 	
 	if ($expected_value) {
 		if ($expected_value ne $current_value) {
 	    	condition_error("I18N_OPENXPKI_SERVER_CONNECTOR_WF_CONDITION_UNEXPECTED_VALUE");
 		} 		
 	} else {
 		if ($current_value) {
 			condition_error("I18N_OPENXPKI_SERVER_CONNECTOR_WF_CONDITION_UNEXPECTED_VALUE");
 		}
 	} 
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WFValue

=head1 SYNOPSIS

  <condition 
     name="field_is_empty" 
     class="OpenXPKI::Server::Workflow::Condition::WFValue">
    <param name="param_name" value="certificate"/>
    <param name="param_value" value=""/>
  </condition>

=head1 DESCRIPTION

Allows for checks of the contents of a scalar value stored in 
the workflow context.

=head1 PARAMETERS

=head2 param_name

The name of the workflow context parameter containing the value to be used

=head2 param_value

Expected value, empty string also matches an undefined parameter. 
