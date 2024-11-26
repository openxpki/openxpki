# OpenXPKI::Server::Workflow::Condition::Connector::Exists
package OpenXPKI::Server::Workflow::Condition::Connector::Exists;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );


sub _evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $path = $self->param('config_path');

    configuration_error('Path is empty') unless ($path);

    my $delimiter = $self->param('delimiter') || '\.';

    if ($delimiter eq '.') { $delimiter = '\.'; }

    my @path = split $delimiter, $path;

    my $exists = CTX('config')->exists( \@path );

    CTX('log')->application()->debug("Condition check for exist: path $path, exist: " . ($exists ? 'yes' : 'no'));


    if (!$exists) {
        condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CONNECTOR_EXISTS_FAILED");
    }

    ##! 32: sprintf 'Path found - ' .$path
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Connector::Exists

=head1 SYNOPSIS

    config_has_node:
        class: OpenXPKI::Server::Workflow::Condition::Connector::Exists
        param:
            config_path: path.of.the.node.to.check


=head1 DESCRIPTION

