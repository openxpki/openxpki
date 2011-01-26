# OpenXPKI::Server::Workflow::Activity::SmartCard::CheckPrereqs
# Written by Scott Hardin for the OpenXPKI project 2010
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::CheckPrereqs;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
	##! 1: 'Entered CheckPrereqs::execute()'
	my $self = shift;
	my $workflow = shift;
	my $context = $workflow->context();
	my $token_id = $context->param('token_id');

	my %params;
	if ($context->param('login_id') ne '') {
	    $params{USERID} = $context->param('login_id');
	}

	my @certs = split(/;/, $context->param('certs_on_card'));

	my $wf_types = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'workflow_types',
	    } );

	my $result = CTX('api')->sc_analyze_smartcard(
	    {
 		CERTS => \@certs,
		CERTFORMAT => 'BASE64',
		SMARTCARDID => $context->param('token_id'),
		WORKFLOW_TYPES => $wf_types->value(),
		CONFIG_ID => $self->config_id(),
		%params,
	     
	    });

	##! 16: 'smartcard analyzed: ' . Dumper $result
	

	# set cert ids in context
	my $cert_ids = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certids_on_card',
	    } );
	$cert_ids->push(
	    map { $_->{IDENTIFIER} } @{$result->{CERTS}}
	    );
	
	
	my $cert_types = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certificate_types',
	    } );

	foreach my $type (keys %{$result->{CERT_TYPE}}) {
	    $cert_types->push($type);

	    foreach my $entry (keys %{$result->{CERT_TYPE}->{$type}}) {
		# FIXME: find a better way to name the flags properly, currently
		# the resulting wf keys depend on the configuration (i. e.
		# configured certificate types)
		
		my $value = 'no';
		if ($result->{CERT_TYPE}->{$type}->{$entry}) {
		    $value = 'yes';
		}

		$context->param('flag_' . $type . '_' . $entry
				=> $value);
	    }
	}

	
	foreach my $flag (keys %{$result->{PROCESS_FLAGS}}) {
	    # propagate flags
	    my $value = 'no';
	    if ($result->{PROCESS_FLAGS}->{$flag}) {
		$value = 'yes';
	    }
	    $context->param('flag_' . $flag => $value);
	}


	# propagate LDAP settings to context
      LDAP_ENTRY:
	foreach my $entry (keys (%{$result->{SMARTCARD}->{assigned_to}})) {
	    my $value = $result->{SMARTCARD}->{assigned_to}->{$entry};
	    if (ref $value eq 'ARRAY') {
		my $queue = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
		    {
			workflow    => $workflow,
			context_key => 'ldap_' . $entry ,
		    } );
		$queue->push(@{$value});
	    } else {
		$context->param('ldap_' . $entry => 
				$result->{SMARTCARD}->{assigned_to}->{$entry});
	    }
	}

	############################################################
	# propagate wf tasks to context
	my $certs_to_install = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certs_to_install',
	    } );
	$certs_to_install->push(
	    @{$result->{TASKS}->{SMARTCARD}->{INSTALL}}
	    );

	my $certs_to_delete = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certs_to_delete',
	    } );
	$certs_to_delete->push(
	    map { $_->{IDENTIFIER} } @{$result->{TASKS}->{SMARTCARD}->{PURGE}}
	    );

	
	my $certs_to_unpublish = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certs_to_unpublish',
	    } );
	$certs_to_unpublish->push(
	    @{$result->{TASKS}->{DIRECTORY}->{UNPUBLISH}}
	    );


	
	$context->param('smartcard_status' =>
			$result->{SMARTCARD}->{status});
	
	$context->param('keysize' =>
			$result->{SMARTCARD}->{keysize});

	$context->param('keyalg' =>
			$result->{SMARTCARD}->{keyalg});
	
	$context->param('smartcard_default_puk' =>
			$result->{SMARTCARD}->{default_puk});
	

	##! 1: 'Leaving Initialize::execute()'
	return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CheckPrereqs

=head1 Description

This activity calls the API for determining which prerequisites have been
met and sets flags for the tasks that are still to be completed.

=head2 Context parameters

The following context parameters set during initialize are read:

token_id, login_id, certs_on_card, owner_id, user_group, token_status

=head1 Functions

=head2 execute

Executes the action.
