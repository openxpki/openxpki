# OpenXPKI::Server::Workflow::Activity::Tools::Export.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Export;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( configuration_error workflow_error );
use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ## get needed informations
    my $context = $workflow->context();
    my $dest    = $self->param('export_destination');
    my $state   = $self->param('export_state');
    my $server  = CTX('xml_config')->get_xpath (
                      XPATH   => [ 'common/database/server_id' ],
                      COUNTER => [ 0 ]);
    my $dir = CTX('xml_config')->get_xpath (
                      XPATH   => [ 'common/data_exchange/export/dir' ],
                      COUNTER => [ 0 ]);
       $dir =~ s{/\s*$}{}xs;

    ## check the parameters
    if (not defined $dest)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_EXPORT_MISSING_DESTINATION' ]];
        $context->param ("__error" => $errors);
        configuration_error ($errors->[0]);
    }
    if (not defined $state)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_EXPORT_MISSING_STATE' ]];
        $context->param ("__error" => $errors);
        configuration_error ($errors->[0]);
    }

    ## build a hash reference with all informations
    my $msg = undef;
    $msg->{'workflow'}->{'type'}        = $workflow->type();
    $msg->{'workflow'}->{'serial'}      = $workflow->id();
    $msg->{'workflow'}->{'state'}       = $state;
    $msg->{'workflow'}->{'last_update'} = $workflow->last_update();
    $msg->{'workflow'}->{'server_id'}   = $server;
    $msg->{'params'} = $context->param();

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
    $context->param ('export_filename' => $filename);
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

=item * export_destination

is the server_id of the destination server.

=item * export_state

is the state on the destination server.

=over

Additionally you must configure the export directory for the data
exchange in config.xml and you must define the server id in the database
configuration correctly.
