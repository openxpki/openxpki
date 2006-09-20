# OpenXPKI::Server::Workflow::Activity::DataExchange::PrepareExportEnv.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::DataExchange::PrepareExportEnv;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Activity OpenXPKI::FileUtils );

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( workflow_error );

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ## set needed informations
    my $context = $workflow->context();

    ## device
    if (defined $self->param ('device'))
    {
        $context->param('device' => $self->param('device'));
    } else {
        $context->param('device' => '/dev/fd0');
    }

    ## dirs of dataexchange
    $context->param ('export' => CTX('xml_config')->get_xpath (
                                     XPATH   => [ 'common/data_exchange/export/dir' ],
                                     COUNTER => [ 0 ]));
    $context->param ('logs' => CTX('xml_config')->get_xpath (
                                     XPATH   => [ 'common/data_exchange/import/dir' ],
                                     COUNTER => [ 0 ]));

    ## name of archive
    my $filename = CTX('xml_config')->get_xpath (
                       XPATH   => [ 'common/server/tmpdir' ],
                       COUNTER => [ 0 ]);
    $context->param ('archive' => $self->get_safe_tmpfile ({TMP => $filename}));
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::PrepareExportEnv

=head1 Description

This activity prepares the environment for an export. The only accepted parameter
is device where you can specify a device which should be used during the export
of the archive.

