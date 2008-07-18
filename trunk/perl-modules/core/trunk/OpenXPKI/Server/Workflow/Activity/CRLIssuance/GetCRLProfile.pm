# OpenXPKI::Server::Workflow::Activity::CRLIsssuance::GetCRLProfile
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CRLIssuance::GetCRLProfile;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::Profile::CRL;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $context    = $workflow->context();

    my $context_ca_ids = $context->param('ca_ids');
    my $ca_ids_ref = $serializer->deserialize($context_ca_ids);
    if (!defined $ca_ids_ref) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_GETCRLPROFILE_CA_IDS_NOT_DESERIALIZED",
        );
    }
    if (!ref $ca_ids_ref eq 'ARRAY') {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_GETCRLPROFILE_CA_IDS_WRONG_TYPE",
        );
    }
    my @ca_ids = @{$ca_ids_ref};
    if (scalar @ca_ids == 0) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_GETCRLPROFILE_NO_CAS_LEFT",
        );
    }

    my $pki_realm = CTX('api')->get_pki_realm();
    ##! 16: 'pki_realm: ' . $pki_realm
    my $profile = OpenXPKI::Crypto::Profile::CRL->new(
            CONFIG    => CTX('xml_config'),
            PKI_REALM => $pki_realm,
            CA        => $ca_ids[0],
            CONFIG_ID => $self->config_id(),
    );
    ##! 16: 'profile: ' . Dumper($profile)
    $context->param('_crl_profile' => $profile);
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRLIssuance::GetCRLProfile

=head1 Description

This activity gets the CRL profile object for the current CA and saves
it in the _crl_profile context value.

