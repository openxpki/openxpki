# OpenXPKI::Server::Workflow::Activity::Tools::PersistCertificateMetadata
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::PersistCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Data::Dumper;

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

    my $metadata = CTX('api')->render_metadata_from_template({
        PROFILE => $profile,
        STYLE   => $style,
        VARS    => $subject_vars
    });

    if (not defined $metadata) {
        CTX('log')->application()->info("No metadata for $profile / $style ");

        return 1;
    }

    ##! 32: 'Metadata is ' . Dumper $metadata

    # Add result to the cert_attributes table
    my $dbi = CTX('dbi');
    foreach my $key (keys(%{$metadata})) {
        my $value = $metadata->{$key};
        next if ($value eq '');
        $value = $ser->serialize( $value ) if (ref $value ne '');

        ##! 32: 'Add new attribute ' . $key . ' value ' . $value

        ## This is a workaround for an upstream bug in the mysql driver
        # we expand a single dash, dot (or e,+) to the verbose "n/a"
        # see https://github.com/openxpki/openxpki/issues/198
        # and https://rt.cpan.org/Public/Bug/Display.html?id=97541

        if ($value =~ m{ \A (-|\.|e|\+) \z }x) {
            $value = 'n/a';
            CTX('log')->application()->debug(sprintf ('Replace metadata dash/dot by verbose "n/a" on %s / %s',
                    $cert_identifier, $key));

        }

        $dbi->insert(
            into => 'certificate_attributes',
            values => {
                attribute_key        => AUTO_ID,
                identifier           => $cert_identifier,
                attribute_contentkey => 'meta_'.$key,
                attribute_value      => $value,
            }
        );
    }
    return 1;

}

1;
