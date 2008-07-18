# OpenXPKI::Server::Workflow::Activity::CertIssuance::GetCertProfile.pm
# Written by Martin Bartosch for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CertIssuance::GetCertProfile;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::Profile::Certificate;

use Data::Dumper;

sub execute
{
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $ca       = $context->param('ca');
    my $id       = $context->param('cert_profile');
    ##! 16: 'context: ' . Dumper($context)

    my $pki_realm = CTX('api')->get_pki_realm();
    ##! 16: 'pki_realm: ' . $pki_realm
    my $profile = OpenXPKI::Crypto::Profile::Certificate->new(
            CONFIG    => CTX('xml_config'),
            PKI_REALM => $pki_realm,
            CA        => $ca,
            ID        => $id,
            TYPE      => 'ENDENTITY', # no self-signed CA certs here(?)
            CONFIG_ID => $self->config_id(),
    );
    ##! 16: 'profile: ' . Dumper($profile)
    $context->param('_cert_profile' => $profile);
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GetCertProfile

=head1 Description

This activity creates a certificate profile object
(OpenXPKI::Crypto::Profile::Certificate), where the type is taken
from the context variable cert_profile and saves it in the context
variable _cert_profile.
