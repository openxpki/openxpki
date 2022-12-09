package OpenXPKI::Server::Workflow::Activity::Tools::PersistCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use Workflow::Exception qw(configuration_error workflow_error);
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database; # to get AUTO_ID

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $params = $self->param();

    my $ser  = OpenXPKI::Serialization::Simple->new();

    my $cert_identifier = $context->param('cert_identifier');
    ##! 16: ' cert_identifier' . $cert_identifier

    # Get the profile name and style
    my $profile = $context->param('cert_profile');
    my $style = $context->param('cert_subject_style');

    if (!$profile) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PERSIST_CERTIFICATE_METADATA_NO_PROFILE',
            params  => { PROFILE => $profile },
        );
    }

    if (!$style) {
        CTX('log')->application()->info("No style defined, skipping metadata");
        return 1;
    }

    my $cert_info  = $context->param('cert_info');
    my $subject_vars = $cert_info ? $ser->deserialize( $cert_info ) : {};
    my $template_vars = $ser->deserialize(  $context->param('cert_subject_parts') );
    foreach my $key (keys %{$template_vars}) {
        $subject_vars->{$key} = $template_vars->{$key} unless(defined $subject_vars->{$key});
    }
    # Add params from the activity definition
    $subject_vars->{data} = $params;

    ##! 32: 'Combined vars hash ' . Dumper $subject_vars

    my $metadata = CTX('api2')->render_metadata_from_template(
        profile => $profile,
        style   => $style,
        vars    => $subject_vars
    );

    if (not defined $metadata) {
        CTX('log')->application()->info("No metadata for $profile / $style ");
        return 1;
    }

    ##! 32: 'Metadata is ' . Dumper $metadata
    CTX('api2')->set_cert_metadata(
        identifier => $cert_identifier,
        attribute  => $metadata,
        mode  => 'merge',
    );

    return 1;

}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PersistCertificateMetadata

=head1 Description

Render and persist the "per profile" metadata for a certificate based
on the template found in the profile definition and the current workflow
context.

All parameters are directly read from the context, activity parameters
are added as extra items to the template input hash.

=head2 Context Items

=over

=item cert_identifier

The identifier of the certificate

=item cert_profile, cert_subject_style

Determines the profile section to read the metadata node from

=item cert_info, cert_subject_parts

Merged together to build the input hash for the template engine, keys
existing in both hashes are taken from I<cert_info>.

=back