# OpenXPKI::Server::Workflow::Activity::DataExchange::BuildArchive.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::DataExchange::BuildArchive;

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

    ## get needed informations
    my $context = $workflow->context();
    my $command = $self->param ('command');
    my $export  = $context->param ('export');
    my $logs    = $context->param ('logs');
    my $archive = $context->param ('archive');

    $command =~ s/__EXPORT_DIR__/$export/;
    $command =~ s/__LOG_DIR__/$logs/;
    $command =~ s/__ARCHIVE__/$archive/;

    `$command`;
    if ($EVAL_ERROR)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_BUILD_ARCHIVE_FAILED',
                        {COMMAND => $command} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::BuildArchive

=head1 Description

This activity builds the archive for an export. The only accepted parameter
is command where you can specify the command to create the archive. Command
knows to three special variables:

=over

=item * __EXPORT_DIR__ which is the directory with exported workflows

=item * __LOG_DIR__ which is the directory with the import logs

=item * __ARCHIVE__ which is the name of the archive which should be created

=back

