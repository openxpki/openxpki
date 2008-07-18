# OpenXPKI::Server::Workflow::Activity::DataExchange::ImportWorkflowInstances.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::ImportWorkflowInstances;

use strict;
use warnings;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity OpenXPKI::FileUtils );

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( workflow_error );
use OpenXPKI::Serialization::Simple;
use Workflow::Factory qw( FACTORY );
use Workflow::Context;
use OpenXPKI::Server::Workflow::Observer::AddExecuteHistory;

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

        ##! 4: "check for an already imported workflow (and deny it)"
        my %hash = ("parent_server_id" => $ref->{workflow}->{server_id});
        my $result = CTX('dbi_workflow')->select
                     (
                         TABLE   => [ [ 'WORKFLOW'         => 'workflow' ],
                                      [ 'WORKFLOW_CONTEXT' => 'context1' ],
                                    ],
                         COLUMNS => [ 'WORKFLOW.WORKFLOW_SERIAL' ],
                         JOIN    => [ [ 'WORKFLOW_SERIAL',
                                        'WORKFLOW_SERIAL'], ],
                         DYNAMIC => {
                                     'workflow.WORKFLOW_TYPE'          => $ref->{workflow}->{type},
                                     'workflow.WORKFLOW_SERIAL'        => $ref->{workflow}->{serial},
                                     'context1.WORKFLOW_CONTEXT_KEY'   => 'parent_server_id',
                                     'context1.WORKFLOW_CONTEXT_VALUE' => $hash{parent_server_id},
                                    },
                     );
        ##! 4: "result from dulicate detection: ".scalar @{$result}
        if (scalar @{$result})
        {
            ##! 8: "detected an already imported workflow"
            next;
        }

        ##! 4: "if workflow does not exist in the database then create it"
        $result = CTX('dbi_workflow')->select
                  (
                      TABLE => 'WORKFLOW',
                      KEY   => $ref->{workflow}->{serial}
                  );
        if (not scalar @{$result})
        {
            ##! 4: "insert workflow into the database"
            CTX('dbi_workflow')->insert (
                TABLE => 'WORKFLOW',
                HASH  => (
                          WORKFLOW_SERIAL      => $ref->{workflow}->{serial},
                          WORKFLOW_TYPE        => $ref->{workflow}->{type},
                          WORKFLOW_STATE       => $ref->{workflow}->{state},
                          WORKFLOW_LAST_UPDATE => $ref->{workflow}->{last_update}
                         ));
        }
        else
        {
            ##! 4: "update workflow in the database"
            CTX('dbi_workflow')->update (
                TABLE => 'WORKFLOW',
                WHERE => {WORKFLOW_SERIAL => $ref->{workflow}->{serial}},
                DATA  => {
                          WORKFLOW_STATE       => $ref->{workflow}->{state},
                          WORKFLOW_LAST_UPDATE => $ref->{workflow}->{last_update}
                         });
        }

        ##! 4: "load the workflow"
        my $wf = FACTORY->fetch_workflow ($ref->{workflow}->{type}, $ref->{workflow}->{serial});
        $wf->delete_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
        $wf->add_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');

        ##! 4: "update the context"
        my $context = Workflow::Context->new();
        $context->param ($ref->{params});
        $context->param ("parent_server_id" => $ref->{workflow}->{server_id});
        $wf->context ($context);

        ##! 4: "execute the first action"
        my @list = $wf->get_current_actions();
        if (not scalar @list)
        {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_IMPORT_WORKFLOW_INSTANCES_NO_NEXT_ACTION",
	        params => {
		    WORKFLOW => $ref->{workflow}->{serial},
	        });
        }
        $wf->execute_action($list[0]);

        ##! 4: "workflow is now persisted"
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::ImportWorkflowInstances

=head1 Description

This activity import all workflow instances which should be imported into
this server.

