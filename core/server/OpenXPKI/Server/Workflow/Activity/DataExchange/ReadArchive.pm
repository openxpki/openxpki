# OpenXPKI::Server::Workflow::Activity::DataExchange::ReadArchive.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::ReadArchive;

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
    my $device   = $context->param ('device');

    $command =~ s/__DEVICE__/$device/;
    $command =~ s/__DIR__/$archive/;

    `$command`;
    if ($EVAL_ERROR)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_READ_ARCHIVE_FAILED',
                        {COMMAND => $command} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::ReadArchive

=head1 Description

This activity reads the archive for an import from a device. The only accepted parameter
is command where you can specify the command to read the archive. Command
knows to two special variables:

=over

=item * __DIR__ which is the place where the archive should name of the archive which should be created

=item * __DEVICE__ which is the name of the device where the archive should be stored

=back

