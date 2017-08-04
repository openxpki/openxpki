# OpenXPKI::Server::Workflow::Activity::CertIssuance::TriggerCertificatePublish
#
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::TriggerCertificatePublish;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;


use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();

    # Add any additional action parameters as context params
    my $params = $self->param();

    my $workflow_type = 'certificate_publishing';

    if ($params->{'workflow_type'}) {
        $workflow_type = $params->{'workflow_type'};
        delete $params->{'workflow_type'};
    }

    # cert identifier is mandatory
    if (!$params->{cert_identifier}) {
        $params->{cert_identifier} = $context->param('cert_identifier');
    }

    # Check profile based publishing if no prefix is set in the action definition
    if (!$params->{prefix}) {
        # Profile based publication, check for publication options
        my $cert_profile = $context->param('cert_profile');
        if (!CTX('config')->get_scalar_as_list(['profile', $cert_profile, 'publish' ] ) &&
            !CTX('config')->get_scalar_as_list(['profile', 'default', 'publish' ] )) {

            ##! 32: 'Publishing not enabled for profile ' . $cert_profile
            CTX('log')->application()->debug('Publishing not enabled for profile ' . $cert_profile);

            return 1;
        }
    }

    # Create publishing workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => $workflow_type,
        PARAMS        => $params
    });

    CTX('log')->application()->info('Publishing workflow created with id ' . $wf_info->{WORKFLOW}->{ID});


    ##! 16: 'Publishing Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}

    $context->param('workflow_publish_id', $wf_info->{WORKFLOW}->{ID} );

    return 1;

}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::TriggerCertificatePublish

=head1 Description

Trigger publication to by starting (unwatched) workflows. The name of the
publication workflow can be given in the activity definition, default is
certificate_publishing.

If no more parameters are given, the publication will happen based on the
publication options of the profile. A workflow is only created if the "publish"
attribute is set in the certificates profile definition or a global publish
rule (in profile.default) exists.

If the parameter I<prefix> is set in the definiton, publication to all
targets at this prefix is startet, regardless if the profile has a publication
option set.

=head1 Configuration

=head2 Activity parameters

=over

=item workflow_type

Name of the workflow that should be created, default is certificate_publishing

=item prefix

Prefix to list of publishing connectors, default is profile based publishing.

=back

All other activity parameters are passed as parameters to the new workflow.
Make sure that those parameters are listed in the initial action of the
called workflow!

=head2 Context parameters

Expects the following context parameter:

=over 12

=item cert_identifier (can be overridden in the an activity definition)

=item cert_profile (obsolete when using prefix)

=back

=head1 Functions

=head2 execute

Executes the action.
