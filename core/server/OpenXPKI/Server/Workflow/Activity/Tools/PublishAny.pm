package OpenXPKI::Server::Workflow::Activity::Tools::PublishAny;

use Moose;
use MooseX::NonMoose;
extends qw( OpenXPKI::Server::Workflow::Activity );
with qw( OpenXPKI::Server::Workflow::Role::Publish );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypt::X509;
use Workflow::Exception qw(configuration_error workflow_error);

sub __get_targets_from_profile {
    configuration_error("You must provide target or prefix for publishing");
}

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $config        = CTX('config');

    my ($prefix, $target) = $self->__fetch_targets();

    # no targets returned
    return unless ($target && $prefix);

    my $publishto = $self->param('key');
    my $data = $self->param('value');

    my $failed = $self->__walk_targets( $prefix, $target, $publishto, $data );

    # pause stops execution of the remaining code
    $self->pause('I18N_OPENXPKI_UI_ERROR_DURING_PUBLICATION') if ($failed);

    ##! 4: 'end'
    return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishAny

=head1 Description

This activity can be used to publish arbitrary data to a set of connectors.

As there is no default path defined, the only supported target selection
mode is by prefix.

=head1 Configuration

=head2 Example

Set the C<prefix> paramater to tell the activity where to find the
connector and pass the payload and an optional name.

    publish_crl:
        class: OpenXPKI::Server::Workflow::Activity::Tools::PublishAny
        param:
            prefix: publishing.trustlist
            _map_key: $listname
            _map_value: $pkcs7

Set up the connector using this syntax

  publishing:
    trustlist:
      repo1@: connector:....
      repo2@: connector:....

=head2 Activity parameters

=over

=item prefix

The prefix where to find the targets.

See OpenXPKI::Server::Workflow::Role::Publish

=item key

The artefact name to send as argument to the publication connector.
Can be empty if not expected by the underlying connector.

=item value

The payload which is passed to the connector as I<data> argument,

=item on_error

Define what to do on problems with the publication connectors. One of:

=over

=item exception (default)

The connector exception bubbles up and the workflow terminates.

=item skip

Skip the publication target and continue with the next one.

=item queue

Similar to skip, but failed targets are added to a queue. As long as
the queue is not empty, pause/wake_up is used to retry those targets
with the retry parameters set. This obvioulsy requires I<retry_count>
to be set.

=back

=back

=head2 Context parameters

=over

=item tmp_publish_queue

Used to temporary store unpublished targets when on_error is set.

=back
