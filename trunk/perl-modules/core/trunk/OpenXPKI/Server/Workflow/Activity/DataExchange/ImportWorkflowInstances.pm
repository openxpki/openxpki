# OpenXPKI::Server::Workflow::Activity::DataExchange::ImportWorkflowInstances.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::DataExchange::ImportWorkflowInstances;

use strict;
use warnings;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity OpenXPKI::FileUtils );

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( workflow_error );
use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ##! 2: "set needed informations"
    my $context = $workflow->context();
    my $logs    = $context->param('local_import_dir');
    my $server  = $context->param ('who_am_i');

    ##! 2: "check if logs was ever used"
    if (not -d $logs and not mkdir $logs)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_IMPORT_WORKFLOW_INSTANCES_MKDIR_FAILED',
                        {DIR => $logs} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }

    ##! 2: "check if there is something to import"
    my $dir = $context->param ('tmpdir')."/export";
    return 1 if (not -d $dir);

    ##! 2: "scan if there is an import directory for this server"
    opendir DIR, $dir;
    my @list = grep /^$server$/, readdir DIR;
    closedir DIR;
    return if (not @list or scalar @list != 1);
    $dir .= "/$server";

    ##! 2: "load all wfe files"
    opendir DIR, $dir;
    @list = grep /^.*\.wfe$/, readdir DIR;
    closedir DIR;
    return if (not @list or scalar @list < 1);
    foreach my $filename (@list)
    {
        ##! 4: "wfe file: $filename"
        my $data = $self->read_file ($dir."/".$filename);
        my $ser  = OpenXPKI::Serialization::Simple->new ();
        my $ref  = $ser->deserialize ($data);

        ##! 4: "create a new workflow instance from the export"
        my %hash = ("parent_workflow_serial" => $ref->{parent}->{workflow_serial},
                    "parent_workflow_type"   => $ref->{parent}->{workflow_type},
                    "parent_server_id"       => $ref->{parent}->{server_id});
        foreach my $item (keys %{$ref->{params}})
        {
            next if ($item eq "parent_workflow_serial");
            next if ($item eq "parent_workflow_type");
            next if ($item eq "parent_server_id");
            $hash{$item} = $ref->{params}->{$item};
        }
        my $api = CTX('api');
        my $workflow = $api->create_workflow_instance (
                             {
                              WORKFLOW      => $ref->{workflow_type},
                              FILTER_PARAMS => 1,
                              PARAMS        => \%hash
                             });
        my $cmd = "echo ".$ref->{parent}->{workflow_serial}." >> $logs/".$ref->{parent}->{server_id}.".log";
        my $ret = `$cmd`;
        if ($EVAL_ERROR)
        {
            my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_IMPORT_WORKFLOW_INSTANCES_LOG_FAILED',
                            {COMMAND => $cmd} ]];
            $context->param ("__error" => $errors);
            workflow_error ($errors->[0]);
        }
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::ImportWorkflowInstances

=head1 Description

This activity import all workflow instances which should be imported into
this server.

