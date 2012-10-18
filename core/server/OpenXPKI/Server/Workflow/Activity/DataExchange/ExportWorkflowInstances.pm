# OpenXPKI::Server::Workflow::Activity::DataExchange::ExportWorkflowInstances.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::ExportWorkflowInstances;

use strict;
use warnings;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( workflow_error );

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ## set needed informations
    my $context = $workflow->context();
    my $export  = $context->param('local_export_dir');

    ## prepare structure of archive
    my $dir = $context->param ('tmpdir')."/export";
    if (not mkdir $dir)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_EXPORT_WORKFLOW_INSTANCES_MKDIR_FAILED',
                        {DIR => $dir} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }

    # copy workflow instances
    my $cmd = "tar -C $export -c . -f - | tar -f - -C ".$context->param ('tmpdir')."/export -x";
    my $ret = `$cmd`;
    if ($EVAL_ERROR)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_EXPORT_WORKFLOW_INSTANCES_COPY_FAILED',
                        {COMMAND => $cmd} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::ExportWorkflowInstances

=head1 Description

This activity copy all workflow instances which should be epxorted to
the temporary export directory.

