# OpenXPKI::Server::Workflow::Activity::CRLIsssuance::DetermineNextCA
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CRLIssuance::DetermineNextCA;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

use DateTime;


sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $context   = $workflow->context();

    my $context_ca_ids = $context->param('ca_ids');
    if (! defined $context_ca_ids) { # undefined, fill context with CA ids
        ##! 4: 'context ca_ids not defined'
        my $api = CTX('api');
        if (!defined $api) {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_DETERMINENEXTCA_API_NOT_DEFINED",
            );
        }
        my $ca_ids = $api->list_ca_ids({
            CONFIG_ID => $self->config_id(),
        });
        if (! defined $ca_ids || ref $ca_ids ne 'ARRAY') {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CRLISSUANCE_DETERMINENEXTCA_NO_CA_IDS_DEFINED',
            );
        }
        my @ca_ids = @{ $ca_ids };
        if (! @ca_ids) {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_DETERMINENEXTCA_CA_IDS_NOT_DEFINED",
            );
        }
        ##! 16: 'ca_ids: ' . Dumper(\@ca_ids)
        my @crl_issuing_cas = (); # only CAs that actually issue CRLs
        my $realms = CTX('pki_realm_by_cfg')->{$self->config_id()};
        ##! 64: 'config_id: ' . $self->config_id()
        ##! 64: 'realms: ' . Dumper $realms

	my $now = DateTime->now( time_zone => 'UTC' );
      CA:
        foreach my $ca_id (@ca_ids) {
            ##! 16: 'ca_id: ' . $ca_id
            ##! 16: Dumper(\$realms->{$pki_realm}->{ca}->{id}->{$ca_id})
	    if (! exists $realms->{$pki_realm}->{ca}->{id}->{$ca_id}->{crl_publication}) {
		##! 32: 'no crl publication configured'
		next CA;
	    }

	    my $ca_notbefore = $realms->{$pki_realm}->{ca}->{id}->{$ca_id}->{notbefore};
	    ##! 16: 'ca_notbefore: ' . Dumper $ca_notbefore
	    
	    my $ca_notafter = $realms->{$pki_realm}->{ca}->{id}->{$ca_id}->{notafter};
	    ##! 16: 'ca_notafter: ' . Dumper $ca_notafter

	    if (DateTime->compare($now, $ca_notbefore) < 0) {
		##! 16: $ca_id . ' is not yet valid, skipping'
		next CA;
	    }
	    if (DateTime->compare($now, $ca_notafter) > 0) {
		##! 16: $ca_id . ' is expired, skipping'
		next CA;
	    }

	    push @crl_issuing_cas, $ca_id;
        }
        ##! 32: 'crl_issung_cas: ' . Dumper(\@crl_issuing_cas)
        my $ca_ids_serialized = $serializer->serialize(\@crl_issuing_cas);
        $context->param('ca_ids' => $ca_ids_serialized);
        # set the ca to the next issuing CA, this is needed for
        # the key usable check
        $context->param('ca' => $crl_issuing_cas[0]);
    }
    else {
        ##! 4: 'context ca_ids defined'
        my $ca_ids_ref = $serializer->deserialize($context_ca_ids);
        if (!defined $ca_ids_ref) {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_DETERMINENEXTCA_CA_IDS_NOT_DESERIALIZED",
            );
        }
        ##! 16: 'ref ca_ids_ref: ' . ref $ca_ids_ref
        if (!ref $ca_ids_ref eq 'ARRAY') {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_DETERMINENEXTCA_CA_IDS_WRONG_TYPE",
            );
        }
        my @ca_ids = @{$ca_ids_ref};
        ##! 16: '@ca_ids: ' . Dumper(\@ca_ids)
        if (scalar @ca_ids == 0) {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_DETERMINENEXTCA_NO_CAS_LEFT",
            );
        }
        shift @ca_ids; # delete first element
        my $ca_ids_serialized = $serializer->serialize(\@ca_ids);
        $context->param('ca_ids' => $ca_ids_serialized);
        if (scalar @ca_ids) {
            # set the ca to the next issuing CA, this is needed for
            # the key usable check
            $context->param('ca' => $ca_ids[0]); 
        }
    }    
    
    ##! 16: Dumper($context)
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRLIssuance::DetermineNextCA

=head1 Description

This activity creates the list of CRL issuing CAs if it is not present yet and
saves a serialized form in the context value ca_ids. If it is present, it
deserializes it, deletes the first entry and saves it to the context again.
The next CA is thus always the first element of the ca_ids array.

Only CAs which are currently valid are considered for CRL issuance.
