# OpenXPKI::Server::Workflow::Activity::DataExchange::ImportLogs.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::ImportLogs;

use strict;
use warnings;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity OpenXPKI::FileUtils );

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( workflow_error );

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ##! 2: "set needed informations"
    my $context = $workflow->context();
    my $export  = $context->param('local_export_dir');
    my $server  = $context->param ('who_am_i');

    ##! 2: "check if there is something to import"
    my $dir = $context->param ('tmpdir')."/logs";
    return 1 if (not -d $dir);

    ##! 2: "scan if there is an import log of the sending server"
    opendir DIR, $dir;
    my @list = grep /^$server\.log$/, readdir DIR;
    closedir DIR;
    return if (not @list or scalar @list != 1);

    ##! 2: "load log informations"
    my $data   = $self->read_file ($dir."/$server.log");
    @list      = split /\n/, $data;
    my $sender = $self->read_file ($context->param ('tmpdir')."/who_am_i");
       $sender =~ s/[\r\n\s]*//g;

    ##! 2: "remove the export files"
    foreach my $wf_id (@list)
    {
        ##! 4: "unlink $export/$sender/${wf_id}.wfe"
        unlink "$export/$sender/${wf_id}.wfe";
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::ImportLogs

=head1 Description

This activity extracts the commited exports and remove these commited
exports from the related export directory.

