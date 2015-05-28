# OpenXPKI::Server::Workflow::Condition::MaxIterationsNotReached.pm
# Written by Oliver Welter for the OpenXPKI project 2009
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::MaxIterationsNotReached;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use English;

use Data::Dumper;

__PACKAGE__->mk_accessors( 'max_count' );
__PACKAGE__->mk_accessors( 'iterator_name' );

sub _init
{
    my ( $self, $params ) = @_;
    unless ( defined $params->{'max_count'}  && defined $params->{'iterator_name'} )    
    {
        configuration_error
             "You must define max_count and iterator_name ",
             "in declaration of condition ", $self->name;
    }
    
    $self->max_count($params->{'max_count'});
    $self->iterator_name($params->{'iterator_name'});
}

sub evaluate {
    
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;
    
    my $context     = $workflow->context();
    
    my $max_count  = $self->max_count;
    my $iterator_name  = 'iterator_'.$self->iterator_name;
    my $iterator_count  = $context->param($iterator_name);
    
    $iterator_count = 0 unless ($iterator_count);
    
    ##! 32: "Iterator check, Name: $iterator_name, Allowed: $max_count, Reached: $iterator_count " 
    
        
    CTX('log')->log(
        MESSAGE => "Iterator check, Name: $iterator_name, Allowed: $max_count, Reached: $iterator_count ",
        PRIORITY => 'debug',
        FACILITY => [ 'application', ],
    ); 
    
	if ($iterator_count >= $max_count) {
	    condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_MAX_ITERATIONS_REACHED");         
	}			
		
	$context->param( $iterator_name => ++$iterator_count );
    return 1;

}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::MaxIterationsNotReached

=head1 SYNOPSIS
 