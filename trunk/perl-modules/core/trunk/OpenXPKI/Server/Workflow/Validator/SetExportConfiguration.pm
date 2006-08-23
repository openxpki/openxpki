package OpenXPKI::Server::Workflow::Validator::SetExportConfiguration;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

__PACKAGE__->mk_accessors( 'params', 'workflow_type', 'destination' );

sub _init {
    my ( $self, $params ) = @_;

    ## check for the presence of the parameters
    foreach my $item ("workflow_type", "destination", "params")
    {
        unless ( exists $params->{$item} )
        {
            configuration_error
                "You must define a value for '$item' in ",
                "declaration of validator ", $self->name;
        }
    }

    ## import the configuration
    $self->workflow_type ($params->{'workflow_type'});
    $self->destination   ($params->{'destination'});
    $self->params        ([split (",", $params->{'params'})]);
}

sub validate {
    my ( $self, $wf ) = @_;

    ## prepare the environment
    my $context = $wf->context();

    ## set the related parameters
    $context->param('export_workflow_type' => $self->workflow_type());
    $context->param('export_destination'   => $self->destination());
    $context->param('export_params'        => $self->params());

    ## return true is senselesse because only exception will be used
    ## but good style :)
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::SetExportConfiguration

=head1 SYNOPSIS

<action name="ExportCSR">
  <validator name="SetExportConfigForOnlineCSR"/>
</action>

<validator name="SetExportConfigForOnlineCSR"
           class="OpenXPKI::Server::Workflow::Validator::SetExportConfiguration">
  <param name="export_workflow_type" value="I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST_OFFLINE"/>
  <param name="export_destination"   value="0"/>
  <param name="export_params"        value="*"/>
</validator>

=head1 DESCRIPTION

This validator fills only the configuration of the export into the workflow
context. If you set * as the value for export_params the you will export
all context parameters. Otherwise you can set a comma separated list of the
parameters which should be exported (e.g. "cert_info,cert_subject").
