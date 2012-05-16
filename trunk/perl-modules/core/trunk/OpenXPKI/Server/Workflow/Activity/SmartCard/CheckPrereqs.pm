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
	if ($context->param('user_id') ne '') {
	    $params{USERID} = $context->param('user_id');
	}

	my @certs = split(/;/, $context->param('certs_on_card'));
	
	my $ser = OpenXPKI::Serialization::Simple->new();

    my @LOGIN_IDS;
    if ($context->param('login_ids')) {
        @LOGIN_IDS = $ser->deserialize( $context->param('login_ids') )
    } 

	my $result = CTX('api')->sc_analyze_smartcard(
	    {
 		CERTS => \@certs,
		CERTFORMAT => 'BASE64',
		SMARTCARDID => $context->param('token_id'),
		SMARTCHIPID => $context->param('chip_id'),
		LOGINIDS => \@LOGIN_IDS,
		WORKFLOW_TYPES => [ qw( I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V2 I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V3 I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK ) ],
		CONFIG_ID => $self->config_id(),
		%params,
	     
	    });

	##! 16: 'smartcard analyzed: ' . Dumper $result
	
    # Save the details on workflows in our context. Note: since complex data
    # structures cannot be persisted without serializing, use the underscore
    # prefix to surpress persisting.

    $context->param('_workflows', $result->{WORKFLOWS});

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
	    	
	
    
    my $config = CTX('config');       
	my @certs_to_create;
	
	foreach my $type (keys %{$result->{CERT_TYPE}}) {
	    $cert_types->push($type);

        # oliwel - create a list of wanted certificates 
        # based on the usable_cert_exists flag and preferred_cert_exists
        # if promote_to_preferred_profile is requested         
        # Assumption: If new certificates for a type are created, we always use
        # the first = preferred profile
        if (!$result->{CERT_TYPE}->{$type}->{usable_cert_exists} ||         	
        	($config->get("smartcard.policy.certs.type.$type.promote_to_preferred_profile" && 
        	!$result->{CERT_TYPE}->{$type}->{preferred_cert_exists}))) {                                    
           
            push @certs_to_create, $type;
                     
        }

	    foreach my $entry (keys %{$result->{CERT_TYPE}->{$type}}) {
		# FIXME: find a better way to name the flags properly, currently
		# the resulting wf keys depend on the configuration (i. e.
		# configured certificate types)
		my $value = 'no';
		if ($result->{CERT_TYPE}->{$type}->{$entry}) {
		    $value = 'yes';
		}

		#$context->param('flag_' . $type . '_' . $entry
	#			   => $value);
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

    # Resolver name that returned the basic user info
    # not used at the moment but might be useful
    $context->param('user_data_source' =>
        $result->{SMARTCARD}->{user_data_source} );

    # Propagate the userinfo to the context
      USERINFO_ENTRY:
	foreach my $entry (keys (%{$result->{SMARTCARD}->{assigned_to}})) {
	    my $value = $result->{SMARTCARD}->{assigned_to}->{$entry};
	    if (ref $value eq 'ARRAY') {
		my $queue = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
		    {
			workflow    => $workflow,
			context_key => 'userinfo_' . $entry ,
		    } );
		$queue->push(@{$value});
	    } else {
		$context->param('userinfo_' . $entry => 
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
	    map { $_->{MODULUS_HASH} } @{$result->{TASKS}->{SMARTCARD}->{PURGE}}
	    );

	
	my $certs_to_unpublish = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
	    {
		workflow    => $workflow,
		context_key => 'certs_to_unpublish',
	    } );
	$certs_to_unpublish->push(
	    map { $_->{IDENTIFIER} } @{$result->{TASKS}->{DIRECTORY}->{UNPUBLISH}}
	    );
	    

   ##! 8: ' Certs to create ' . Dumper @certs_to_create
    my $certs_to_create_wf = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {
        workflow    => $workflow,
        context_key => 'certs_to_create',
        } );
    $certs_to_create_wf->push(
        @certs_to_create
        );

	
	$context->param('smartcard_status' =>
			$result->{SMARTCARD}->{status});
	
	$context->param('keysize' =>
			$result->{SMARTCARD}->{keysize});

	$context->param('keyalg' =>
			$result->{SMARTCARD}->{keyalg});

    # Values are valid, new, mismatch	
	$context->param('smartcard_token_chipid_match' =>
			$result->{SMARTCARD}->{token_chipid_match});

    # Record the max validity - sc_analyse returns an epoch, we need a terse date    
    if ($result->{VALIDITY}->{set_to_value}) {
        my $max_validity = OpenXPKI::DateTime::convert_date({
            DATE      => DateTime->from_epoch( epoch => $result->{VALIDITY}->{set_to_value} ),
            OUTFORMAT => 'terse',
        });
        $context->param('max_validity' => $max_validity);
    } else {
        $context->param('max_validity' => 0);
    }

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
