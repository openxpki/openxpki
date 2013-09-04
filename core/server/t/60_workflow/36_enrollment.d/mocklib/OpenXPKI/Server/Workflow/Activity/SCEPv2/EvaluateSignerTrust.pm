package OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateSignerTrust;

use strict;

use base qw( Workflow::Action );

#use OpenXPKI::Server::Context qw( CTX );
#use OpenXPKI::Exception;
#use OpenXPKI::Debug;
#use OpenXPKI::Crypto::CSR;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
#    my $pki_realm  = CTX('session')->get_pki_realm();
#    my $cfg_id     = $self->config_id();

    my $context   = $workflow->context();
#    my $server    = $context->param('server');

    # Set static policy for our test CA
#    $context->param( p_allow_anon_enroll => 0 );
#    $context->param( p_allow_man_authen => 0 );
#    $context->param( p_max_active_certs => 1 );


    return 1;
}

1;

