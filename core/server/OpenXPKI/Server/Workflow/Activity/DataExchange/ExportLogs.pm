# OpenXPKI::Server::Workflow::Activity::DataExchange::ExportLogs.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::ExportLogs;

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
    my $logs    = $context->param('local_import_dir');
    my $server  = $context->param('who_am_i');
    my $dest    = $context->param('destination');

    ## document who is the sender
    my $cmd = "echo $server > ".$context->param ('tmpdir')."/who_am_i";
    my $ret = `$cmd`;
    if ($EVAL_ERROR)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_EXPORT_LOGS_WHO_AM_I_FAILED',
                        {COMMAND => $cmd} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }

    ## prepare log directory in archive
    my $dir = $context->param ('tmpdir')."/logs";
    if (not mkdir $dir)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_EXPORT_LOGS_MKDIR_FAILED',
                        {DIR => $dir} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }

    # copy logs
    $cmd = "cp $logs/$dest.log ".$context->param ('tmpdir')."/logs/";
    $ret = `$cmd`;
    if ($EVAL_ERROR)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_EXPORT_LOGS_COPY_FAILED',
                        {COMMAND => $cmd} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }

    ## drop old logs
    if (-e "$logs/$dest.log" and not unlink "$logs/$dest.log")
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_EXPORT_LOGS_UNLINK_FAILED',
                        {FILENAME => "$logs/$dest.log"} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::ExportLogs

=head1 Description

This activity copy all import logs to the temporary export directory.

