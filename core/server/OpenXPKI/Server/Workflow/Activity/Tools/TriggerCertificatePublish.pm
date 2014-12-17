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

    my $workflow_type = $self->param('workflow_type');

    $workflow_type = 'certificate_publishing' unless($workflow_type);

    my $cert_identifier = $context->param('cert_identifier');

    my $params = {
        cert_identifier =>  $cert_identifier
    };

    # Check if a prefix is set in the action definition
    my $prefix = $self->param('prefix');
    if ($prefix) {
        $params->{prefix} = $prefix;
    } else {
        # Profile based publication, check for publication options
        my $cert_profile = $context->param('cert_profile');
        if (!CTX('config')->get_scalar_as_list(['profile', $cert_profile, 'publish' ] ) &&
            !CTX('config')->get_scalar_as_list(['profile', 'default', 'publish' ] )) {

            ##! 32: 'Publishing not enabled for profile ' . $cert_profile
            CTX('log')->log(
                MESSAGE  => 'Publishing not enabled for profile ' . $cert_profile,
                PRIORITY => 'debug',
                FACILITY => 'application',
            );
            return 1;
        }
    }

    # Create publishing workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => $workflow_type,
        PARAMS        => $params
    });

    CTX('log')->log(
        MESSAGE  => 'Publishing workflow created with id ' . $wf_info->{WORKFLOW}->{ID},
        PRIORITY => 'info',
        FACILITY => 'application',
    );

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

=head2 Context parameters

Expects the following context parameter:

=over 12

=item cert_identifier

=back

=head1 Functions

=head2 execute

Executes the action.
