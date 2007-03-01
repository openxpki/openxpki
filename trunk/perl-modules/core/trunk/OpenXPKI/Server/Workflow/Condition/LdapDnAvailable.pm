## OpenXPKI::Server::Workflow::Condition::LdapDnAvailable
## Written 2007 by Peter Grigoriev for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
## $Revision 008$

package OpenXPKI::Server::Workflow::Condition::LdapDnAvailable;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Condition::LdapDnAvailable';
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
 my $realm_config = CTX('pki_realm')->{$pki_realm};

        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_enable}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_excluded_roles}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_suffix}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_server}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_port}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_version}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_tls}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_sasl}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_chain}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_login}
        ##! 128 'LDAP CONDITION '. $realm_config->{ldap_password}

 return 1;
}

1;

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

This condition must check if the certificate 
distinguished name is found in ldap tree. 
At the moment always returns TRUE.
