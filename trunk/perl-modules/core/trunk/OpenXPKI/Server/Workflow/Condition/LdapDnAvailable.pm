## OpenXPKI::Server::Workflow::Condition::LdapDnAvailable
## Written 2007 by Peter Grigoriev for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::LdapDnAvailable;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;
use utf8;
use Net::LDAP;
use English;

sub _init
{
    my ( $self, $params ) = @_;

    return 1;
}

sub evaluate
{
 my ( $self, $workflow ) = @_;

 my $pki_realm = CTX('api')->get_pki_realm(); 
 my $cfg_id = CTX('api')->get_config_id({ ID => $workflow->id() });
 my $realm_config = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm};
 my $context  = $workflow->context();


 my $node_exist  = $context->param('node_exist');

 if ( $node_exist eq 'no' ){
       ##! 129: 'LDAP PUBLIC CONDITION node NOT FOUND'
       condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECK_DN_LDAP_NODE_DOES_NOT_EXIST");
 };	  
 return 1;
}

1;


#-----------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::LdapDnAvailable

=head1 SYNOPSIS

<action name="do_something">
  <condition name="ldap_dn_available"
             class="OpenXPKI::Server::Workflow::Condition::LdapDnAvailable">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks if the LDAP node exists where the certificate is assumed to be published. 

