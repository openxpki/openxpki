# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::Tools::DetermineIssuingCA;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::DateTime;

# use Smart::Comments;

sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->SUPER::execute($workflow,
			  {
			      # CHOOSE one of the following:
			      # CA: CA operation (default)
			      # RA: RA operation
			      # PUBLIC: publicly available operation
			      ACTIVITYCLASS => 'CA',
			      PARAMS => {
				  profile => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
			      },
			  });    


    # you may wish to use these shortcuts
    my $context      = $workflow->context();
#     my $activity     = $self->{ACTIVITY};
    my $pki_realm    = $self->{PKI_REALM};
#     my $session      = $self->{SESSION};
#     my $defaulttoken = $self->{TOKEN_DEFAULT};


    my $realm_config = CTX('pki_realm')->{$pki_realm};

    my $profilename = $self->param('profile');

    if (! exists $realm_config->{endentity}->{id}->{$profilename}->{validity}) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_TOOLS_DETERMINEISSUINGCA_NO_MATCHING_PROFILE",
	    params  => {
		REQUESTED_PROFILE => $profilename,
	    },
	    );
    }

    # get validity as specified in the configuration
    my $entry_validity 
	= $realm_config->{endentity}->{id}->{$profilename}->{validity};


    my $requested_notbefore;
    my $requested_notafter;

    if (! exists $entry_validity->{notbefore}) {
	# assign default (current timestamp) if notbefore is not specified
	$requested_notbefore = DateTime->now( time_zone => 'UTC' );
    } else {
	$requested_notbefore = OpenXPKI::DateTime::get_validity(
	    {
		VALIDITY => $entry_validity->{notbefore}->{validity},
		VALIDITYFORMAT => $entry_validity->{notbefore}->{format},
	    },
	    );
    }

    $requested_notafter = OpenXPKI::DateTime::get_validity(
	    {
		REFERENCEDATE => $requested_notbefore,
		VALIDITY => $entry_validity->{notafter}->{validity},
		VALIDITYFORMAT => $entry_validity->{notafter}->{format},
	    },
	);


    # anticipate runtime differences, if the requested notafter is close
    # to the end a CA validity we might identify an issuing CA that is
    # not able to issue the certificate anymore when the actual signing
    # action begins
    # FIXME: is this acceptable?
    $requested_notafter->add( minutes => 5 );

    ### requested notbefore: $requested_notbefore->datetime()
    ### requested notafter: $requested_notafter->datetime()


    # iterate through all issuing CAs and determine possible candidates
    # for issuing the requested certificate
    my $now = DateTime->now( time_zone => 'UTC' );
    my $intca;
    my $mostrecent_notbefore;
  CANDIDATE:
    foreach my $ca_id (sort keys %{ $realm_config->{ca}->{id} }) {
	### Internal CA: $ca_id

	my $ca_notbefore = $realm_config->{ca}->{id}->{$ca_id}->{notbefore};
	###   NotAfter: $ca_notbefore->datetime()

	my $ca_notafter = $realm_config->{ca}->{id}->{$ca_id}->{notafter};
	###   NotBefore: $ca_notafter->datetime()

	# check if issuing CA is valid now
	if (DateTime->compare($now, $ca_notbefore) <= 0) {
	    ###   Internal CA is not valid yet, skipping...
	    next CANDIDATE;
	}
	if (DateTime->compare($now, $ca_notafter) >= 0) {
	    ###   Internal CA is not valid any more, skipping...
	    next CANDIDATE;
	}

	# check if requested validity fits into the ca validity
	if (DateTime->compare($requested_notbefore, $ca_notbefore) <= 0) {
	    ###   requested NotBefore does not fit in CA validity...
	    next CANDIDATE;
	}
	if (DateTime->compare($requested_notafter, $ca_notafter) >= 0) {
	    ###   requested NotAfter does not fit in CA validity...
	    next CANDIDATE;
	}

	# check if this CA has a more recent NotBefore date
	if (defined $mostrecent_notbefore)
	{
	    if (DateTime->compare($ca_notbefore, $mostrecent_notbefore) > 0)
	    {
		###    Issuing CA has a more recent NotBefore date than the previous one
		$mostrecent_notbefore = $ca_notbefore;
		$intca = $ca_id;
	    }
	}
	else
	{
	    ###    First candidate...
	    $mostrecent_notbefore = $ca_notbefore;
	    $intca = $ca_id;
	}
    }

    if (! defined $intca) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_TOOLS_DETERMINEISSUINGCA_NO_MATCHING_CA",
	    params  => {
		REQUESTED_NOTAFTER => $requested_notafter->iso8601(),
	    },
	    );
    }

    $context->param(ca => $intca);

    $workflow->add_history(
        Workflow::History->new({
            action      => 'Determine Issuing CA',
            description => sprintf( "Determined issuing CA: %s",
		$intca),
            user        => $self->param('creator'),
			       })
	);
    
}


1;

=head1 Description

Implements the FIXME workflow action.

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
