# OpenXPKI::Server::Workflow::Activity::DataExchange::Cleanup.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::DataExchange::Cleanup;

use strict;
use warnings;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use File::Path;
use File::Basename;

## FIXME: why does the inheritance from Activity does not work?
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( workflow_error );

sub execute
{
    my $self = shift;
    my $workflow = shift;

    ## set needed informations
    my $context = $workflow->context();
    my $archive = $context->param ('archive_directory');
    my $tmp     = $context->param ('tmpdir');

    foreach my $dir ($archive, $tmp)
    {
        if (not rmtree($dir, 0, 1))
        {
            my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_DATAEXCHANGE_CLEANUP_RMTREE_FAILED',
                            {DIR => $dir} ]];
            $context->param ("__error" => $errors);
            workflow_error ($errors->[0]);
        }
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::DataExchange::Cleanup

=head1 Description

This activity removes all temporary directories and files from the system.

