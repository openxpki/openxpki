# OpenXPKI::Server::Workflow::Activity::Tools::DetermineIssuingCA
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
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;

    # you may wish to use these shortcuts
    my $context      = $workflow->context();
    my $pki_realm    = $self->{PKI_REALM};
    ##! 16: 'pki_realm: ' . $pki_realm
    my $realm_config = CTX('pki_realm_by_cfg')->{$self->{CONFIG_ID}}
                                              ->{$pki_realm};
    ##! 128: 'realm_config: ' . Dumper $realm_config

    my $profilename = $context->param('cert_profile'); # was 'profile'
    ##! 16: 'profilename: ' . $profilename

    if (! exists $realm_config->{endentity}->{id}->{$profilename}->{validity}) {
        OpenXPKI::Exception->throw(
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
    ##! 64: 'requested_notbefore: ' . Dumper $requested_notbefore
    ##! 64: 'request_notafter: ' . Dumper $requested_notafter


    # anticipate runtime differences, if the requested notafter is close
    # to the end a CA validity we might identify an issuing CA that is
    # not able to issue the certificate anymore when the actual signing
    # action begins
    # FIXME: is this acceptable?
    if ($entry_validity->{notafter}->{format} eq 'relativedate') {
        $requested_notafter->add( minutes => 5 );
    }        
    ##! 64: 'request_notafter (+5m?): ' . Dumper $requested_notafter

    # iterate through all issuing CAs and determine possible candidates
    # for issuing the requested certificate
    my $now = DateTime->now( time_zone => 'UTC' );
    my $intca;
    my $mostrecent_notbefore;
  CANDIDATE:
    foreach my $ca_id (sort keys %{ $realm_config->{ca}->{id} }) {
        ##! 16: 'ca_id: ' . $ca_id

        my $ca_notbefore = $realm_config->{ca}->{id}->{$ca_id}->{notbefore};
        ##! 16: 'ca_notbefore: ' . Dumper $ca_notbefore

        my $ca_notafter = $realm_config->{ca}->{id}->{$ca_id}->{notafter};
        ##! 16: 'ca_notafter: ' . Dumper $ca_notafter

        if (! defined $ca_notbefore || ! defined $ca_notafter) {
            ##! 16: 'ca_notbefore or ca_notafter undef, skipping'
            next CANDIDATE;
        }
        # check if issuing CA is valid now
        if (DateTime->compare($now, $ca_notbefore) < 0) {
            ##! 16: $ca_id . ' is not yet valid, skipping'
            next CANDIDATE;
        }
        if (DateTime->compare($now, $ca_notafter) > 0) {
            ##! 16: $ca_id . ' is expired, skipping'
            next CANDIDATE;
        }

        # check if requested validity fits into the ca validity
        if (DateTime->compare($requested_notbefore, $ca_notbefore) < 0) {
            ##! 16: 'requested notbefore does not fit in ca validity'
            next CANDIDATE;
        }
        if (DateTime->compare($requested_notafter, $ca_notafter) > 0) {
            ##! 16: 'requested notafter does not fit in ca validity'
            next CANDIDATE;
        }

        # check if this CA has a more recent NotBefore date
        if (defined $mostrecent_notbefore)
        {
            ##! 16: 'mostrecent_notbefore: ' . Dumper $mostrecent_notbefore
            if (DateTime->compare($ca_notbefore, $mostrecent_notbefore) > 0)
            {
                ##! 16: $ca_id . ' has an earlier notbefore data'
                $mostrecent_notbefore = $ca_notbefore;
                $intca = $ca_id;
            }
        }
        else
        {
            ##! 16: 'new mostrecent_notbefore'
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
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::DetermineIssuingCA

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
