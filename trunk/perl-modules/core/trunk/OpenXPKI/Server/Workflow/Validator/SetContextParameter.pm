package OpenXPKI::Server::Workflow::Validator::SetContextParameter;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

__PACKAGE__->mk_accessors( 'params' );

sub _init {
    my ( $self, $params ) = @_;

    ## make a deep copy of the configuration
    $self->params        ({%{$params}});
}

sub validate {
    my ( $self, $wf ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $params  = $self->params();
    delete $params->{name};
    delete $params->{class};

    ## set the parameters
    $context->param ($params);

    ## return true is senselesse because only exception will be used
    ## but good style :)
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::SetContextParameter

=head1 SYNOPSIS

<action name="ExportCSR">
  <validator name="SetExportConfigForOnlineCSR"/>
</action>

<validator name="SetExportConfigForOnlineCSR"
           class="OpenXPKI::Server::Workflow::Validator::SetContextParameter">
  <param name="export_workflow_type" value="I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST_OFFLINE"/>
  <param name="export_destination"   value="0"/>
  <param name="export_params"        value="*"/>
</validator>

=head1 DESCRIPTION

This validator can be used to configure statical context parameters which
is otherwise impossible with the Workflow package.

This example fills only the configuration of the export into the workflow
context. If you set * as the value for export_params the you will export
all context parameters. Otherwise you can set a comma separated list of the
parameters which should be exported (e.g. "cert_info,cert_subject").
