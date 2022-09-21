package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::ClearNamespace;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Workflow::Exception qw(configuration_error);

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    configuration_error('Mandatory parameter namespace missing or empty') unless($self->param('namespace'));

    CTX('api2')->clear_data_pool_namespace(
        namespace => $self->param('namespace'),
    );

    CTX('log')->application()->info('Cleared datapool namespace '.$self->param('namespace'));

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::ClearNamespace

=head1 Description

Delete the entire datapool namespace defined by C<namespace>.

=head1 Configuration

=head2 Activity Paramaters

=over

=item namespace

=back
