# OpenXPKI::Server::Workflow::Activity::CertLdapPublish::AddMissingNode
# Written by Petr Grigoriev for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project
# $Revision$


package OpenXPKI::Server::Workflow::Activity::CertLdapPublish::AddMissingNode;

use strict;

use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CertLdapPublish::AddMissingNode';

sub execute {
 my $self = shift;
 my $workflow = shift;
 
 $self->SUPER::execute($workflow,
			  {
                           ACTIVITYCLASS => 'CA',
			   PARAMS => {
			   },
			  });    

 my $pki_realm = CTX('api')->get_pki_realm();
 my $realm_config = CTX('pki_realm')->{$pki_realm};

        ##! 128 'LDAP ACTION '. $realm_config->{ldap_enable}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_excluded_roles}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_suffix}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_server}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_port}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_version}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_tls}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_sasl}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_chain}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_login}
        ##! 128 'LDAP ACTION '. $realm_config->{ldap_password}

return 1;
}

1;

__END__
=head1 Name

OpenXPKI::Server::Workflow::Activity::CertLdapPublish::AddMissingNode

=head1 Description

This activity is assumed to add missing LDAP node to build a valid DN
for adding a certificate. Doing nothing at the moment.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item ...

Description...

=item ...

Description...

=back

After completion the following context parameters will be set:

=over 12

=item ...

Description...

=back

=head1 Functions

=head2 execute

Executes the action.
