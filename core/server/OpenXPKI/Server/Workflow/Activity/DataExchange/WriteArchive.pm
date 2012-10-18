# OpenXPKI::Server::Workflow::Activity::DataExchange::WriteArchive.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::WriteArchive;

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
    my $context  = $workflow->context();
    my $command  = $self->param ('command');
    my $archive  = $context->param ('archive_directory');
    my $filename = $context->param ('archive_filename');
    my $device   = $context->param ('device');

    $command =~ s/__DEVICE__/$device/;
    $command =~ s/__ARCHIVE__/$filename/;

    if (not chdir $archive)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_WRITE_ARCHIVE_DIR_MISSING',
                        {DIR => $archive} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
    `$command`;
    if ($EVAL_ERROR)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_WRITE_ARCHIVE_FAILED',
                        {COMMAND => $command} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::WriteArchive

=head1 Description

This activity write the archive for an export to a device. The only accepted parameter
is command where you can specify the command to write the archive. Command
knows to two special variables:

=over

=item * __ARCHIVE__ which is the name of the archive which should be created

=item * __DEVICE__ which is the name of the device where the archive should be stored

=back

