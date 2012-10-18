# OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs.pm
# Written by Scott Hardin for the OpenXPKI project 2009
#
# Based on OpenXPKI::Server::Workflow::Condition::IsValidSignature.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;

use English;

use Data::Dumper;

sub evaluate {
	##! 16: 'start'
    ##! 128: 'auth1_id_mail  = ' . $context->param('auth1_id_mail')
    ##! 128: 'auth2_id_mail  = ' . $context->param('auth2_id_mail')
	my ( $self, $workflow ) = @_;
	my $context = $workflow->context(); 
	
	if ( $context->param('auth1_ldap_mail') and $context->param('auth2_ldap_mail') ) {
		return 1;
	} else {
		condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_NO_AUTH_IDS');
		return -1;
	}
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs

=head1 SYNOPSIS

<action name="do_something">
  <condition name="valid_signature_with_requested_dn"
             class="OpenXPKI::Server::Workflow::Condition::Smartcard::HaveAuthIDs">
  </condition>
</action>

=head1 DESCRIPTION

Checks whether the IDs for the authorizing persons have been set.
