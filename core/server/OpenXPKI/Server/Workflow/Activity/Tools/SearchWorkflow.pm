package OpenXPKI::Server::Workflow::Activity::Tools::SearchWorkflow;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::DateTime;
use DateTime;
use Workflow::Exception qw(configuration_error);


sub execute {
    
    my $self = shift;
    my $workflow = shift;
    
    my $context = $workflow->context();
    
    my $target_key = $self->param('target_key') || 'search_result';
    
    my $query;
    if ($self->param('wf_type')) {
        $query->{TYPE} = $self->param('wf_type');        
    }
    if ($self->param('wf_state')) {
        $query->{STATE} = $self->param('wf_state');        
    }

    my @attr;
    if ($self->param('wf_creator')) {
        push @attr, { KEY => 'creator', VALUE => ~~ $self->param('wf_creator') };
    }
    
    foreach my $key ($self->param()) {
        ##! 16: 'Param key ' . $key
        next unless $key =~ /attr_(\w+)/;
        push @attr, { KEY => $1, VALUE => ~~ $self->param($key) };
    }
    
    $query->{ATTRIBUTE} = \@attr;
    
    ##! 16: 'Query ' . Dumper $query

    my $result_count = CTX('api')->search_workflow_instances_count( $query );
    
    if ($result_count > 1) {
        configuration_error('Ambigous configuration - more than one result found');
    } elsif ($result_count == 0) {
        $context->param( $target_key => '' );
    } else {
        my $result = CTX('api')->search_workflow_instances( $query );
        ##! 32: 'Result' . Dumper $result
        my $wf_id = $result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'};
        $context->param( $target_key => $wf_id );
    }

    return 1;    
    
}


1;

__END__;

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SearchWorkflow

=head1 Description

Load the policy section for a server endpoint. 

The path to load defaults to $interface.$server.policy where interface
and server are read from the context. You can override the full path by 
setting the key I<config_path>.

The given path is expected to return a hash, each key/value pair is read 
into  the context with the I<p_> prefix added to each key! 

=head2 Activity Parameter

=over

=item config_path

Explict path to read the policy from.

=back