# OpenXPKI::Server::Workflow::Activity::Tools::Export.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::Tools::Export;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( workflow_error );
use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ## get needed informations
    my $context = $workflow->context();
    my $type    = $context->param('export_workflow_type');
    my $params  = $context->param('export_params');
    my $dest    = $context->param('export_destination');
    my $server  = CTX('xml_config')->get_xpath (
                      XPATH   => [ 'common/database/server_id' ],
                      COUNTER => [ 0 ]);
    my $dir = CTX('xml_config')->get_xpath (
                      XPATH   => [ 'common/data_exchange/export/dir' ],
                      COUNTER => [ 0 ]);
       $dir =~ s{/\s*$}{}xs;

    ## build a hash reference with all informations
    my $msg = undef;
    $msg->{'workflow_type'} = $context->param('export_workflow_type');
    $msg->{'parent'}->{'workflow_serial'} = $workflow->id();
    $msg->{'parent'}->{'workflow_type'}   = $workflow->type();
    $msg->{'parent'}->{'server_id'}       = $server;
    $params = [ split ",", $params ];
    if ($params->[0] eq "*")
    {
        $msg->{'params'} = $context->param();
    }
    else
    {
        foreach my $item (sort @{$params})
        {
            $msg->{'params'}->{$item} = $context->param($item);
        }
    }

    ## serialize the message
    my $serializer = OpenXPKI::Serialization::Simple->new ({SEPARATOR => '-'});
    $msg = $serializer->serialize ($msg);

    ## check that the export directory exists
    my @dirs = ();
    push @dirs, (substr ($dir, 0, rindex ($dir, "/")));
    push @dirs, $dir;
    push @dirs, $dir."/".$dest;
    foreach my $path (@dirs)
    {
        if (not -d $path and
            not mkdir $path, 0700)
        {
            my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_EXPORT_MKDIR_FAILED',
                            {DIR => $path} ]];
            $context->param ("__error" => $errors);
            workflow_error ($errors->[0]);
        }
    }

    ## write message to the correct export directory
    my $filename = $dir."/".$dest."/".$workflow->id().".wfe";
    if (not open FD, ">$filename")
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_EXPORT_OPEN_FAILED',
                        {FILENAME => $filename} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
    print FD $msg;
    close FD;

    # workflow is now serialized in the export directory
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Export

=head1 Description

This activity exports the data from a workflow to the filesystem. The
activity is used for the data exchange with other server. The exported
workflow ican be found in the export directory of the data exchange.

=head1 Configuration

You must specifiy the following parameters in the action:

=over

=item * export_workflow_type

This is the workflow type at the other server where the workflow will
be created from the exported data-

=item * export_params

is a comma seperated list of the variables which should be exported
from the workflow context. If you use "*" as value then all parameters
will be exported.

=item * export_destination

is the server_id of the destination server.

=over

Additionally you must configure the export directory for the data
exchange in config.xml and you must define the server id in the database
configuration correctly.
