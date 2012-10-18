# OpenXPKI::Server::Workflow::Activity::DataExchange::UnpackArchive.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::UnpackArchive;

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
    my $export   = $context->param ('tmpdir');
    my $archive  = $context->param ('archive_directory');
    my $filename = $context->param ('archive_filename');

    $command =~ s/__DIR__/$export/;
    $command =~ s/__ARCHIVE__/$archive\/$filename/;

    `$command`;
    if ($EVAL_ERROR)
    {
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_UNPACK_ARCHIVE_FAILED',
                        {COMMAND => $command} ]];
        $context->param ("__error" => $errors);
        workflow_error ($errors->[0]);
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::UnpackArchive

=head1 Description

This activity unpacks the archive for an import. The only accepted parameter
is command where you can specify the command to create the archive. Command
knows to three special variables:

=over

=item * __ARCHIVE__ which is the name of the archive which should be created

=item * __DIR__ which is the name of the directory where the content of the
        archive should be restored

=back

