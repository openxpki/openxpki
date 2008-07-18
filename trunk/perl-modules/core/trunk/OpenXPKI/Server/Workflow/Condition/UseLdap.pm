## OpenXPKI::Server::Workflow::Condition::UseLdap
## Written 2007 by Peter Grigoriev for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::UseLdap;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub _init
{
    my ( $self, $params ) = @_;

    return 1;
}

sub evaluate
{
 my ( $self, $wf ) = @_;

 my $pki_realm = CTX('api')->get_pki_realm();
 my $cfg_id = CTX('api')->get_config_id({ ID => $wf->id() });
 my $realm_config = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm};

 if ($realm_config->{ldap_enable} ne 'yes') {
     condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_LDAP_DISABLED");
 }
 return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::UseLdap

=head1 SYNOPSIS

<action name="do_something">
  <condition name="use_ldap"
             class="OpenXPKI::Server::Workflow::Condition::UseLdap">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks the ldap- flag in realm to enable or disable
forking the certificate_issue workflow for publishing the certificate 
using LDAP.
The flag is set in  config.xml ("yes" or "no").
