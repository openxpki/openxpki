# OpenXPKI::Server::Workflow::Activity::SCEPv2::FetchGroupPolicy
# Written by Scott Hardin for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::FetchGroupPolicy;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
#use OpenXPKI::Crypto::CSR;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context   = $workflow->context();
    my $config = CTX('config');
    
    my $server = $context->param('server');
    
#    my $pki_realm  = CTX('session')->data->pki_realm;

    my @policy_params = $config->get_keys("scep.$server.policy");

    foreach my $key (@policy_params) {
        $context->param( "p_$key" => $config->get("scep.$server.policy.$key") );        
    }

    CTX('log')->application()->debug("SCEP policy loaded for $server");
        

    # Set static policy for our test CA
    #$context->param( p_allow_anon_enroll => 0 );
    #$context->param( p_allow_man_authen => 0 );
    #$context->param( p_max_active_certs => 1 );

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::FetchGroupPolicy

=head1 Description

This activity fetches the group policy for the SCEPv2 workflow.

The policy is read from the config connector at scep.$server.policy where
server is the name of the server instance as given by the scep client.
The I<p_> prefix is always added by the activitiy! 


