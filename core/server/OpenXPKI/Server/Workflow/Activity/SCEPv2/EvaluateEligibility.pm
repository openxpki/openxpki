# OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility;
        
use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    
    my $context   = $workflow->context();
    my $config = CTX('config');
    
    # To make support a bit easier, we write the operation mode
    # verbosely to the context (its in there already!)
     
    my $is_initial = ( !$context->param( 'signer_trusted' ) && $context->param('signer_sn_matches_csr' ) );
    
    $context->param( 'request_mode' => ( $is_initial ? 'initial' : 'renewal' ) );
    
    ##! 16: 'request_mode ' . $context->param( 'request_mode' )

    # just check the connector for the current mode    

    my $server = $context->param('server'); 
        
    $context->param('eligible_for_initial_enroll' => 0);
    $context->param('eligible_for_renewal' => 0);       
                  
    my ($flag, $prefix, $value, $query, $res);

    if ($is_initial) {
        $prefix = [ 'scep', $server, 'eligible','initial' ];
        $flag = 'eligible_for_initial_enroll';
    } else {
        $prefix = [ 'scep', $server, 'eligible','renewal' ];       
        $flag = 'eligible_for_renewal';
    }        
    
=cut
    ## FIXME - syntax for path building needs to be defined and implemented    
    $value = $config->get( [ $prefix, 'value' ] );    
    $query = $context->param($value) if ($value);
    
    ##! 16: 'Lookup using ' . $value . ' which is ' . $query
    if ($query) {
        $res = $config->get( [ $prefix, 'source', $query ] ) ;
        ##! 32: 'result is ' . $res 
        $context->param($flag => $res );         
    }
=cut

    $context->param('todo_kludge_eligibility_check'  => 'fix in Activity::SCEPv2::EvaluateEligibility');
    
    ## FIXME - always true for now
    ## Also needs update to workflow (workflow should not fail on failed eligible check) 
    my $res = 1;
    $context->param( $flag => 1);
        
    CTX('log')->log(
        MESSAGE => "SCEP Eligibility for " . 
            ($is_initial ? 'initial enrollment ' : 'renewal ' ) .
            ($res ? 'granted' : 'failed'),
        PRIORITY => 'info',
        FACILITY => ['audit','system'],
    );       
    
    
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility

=head1 Description

Check the eligability to perform initial enrollment or renewal against the 
connector. The activity detects if we are in initial or renewal mode and 
writes the decission to "request_mode".
The data source must be configured in the config of the running scep 
server:

  scep-server-1:
    eligible:
      initial:
        source@: connector: your.connector 
        value: cert_subject

      renewal: ''
        
For inital enrollment, the given connector is queried using the requested
subject as parameter. Renewal is disabled as the path is empty.
        
        