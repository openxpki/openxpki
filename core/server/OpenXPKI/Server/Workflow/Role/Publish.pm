package OpenXPKI::Server::Workflow::Role::Publish;

use Moose::Role;

use strict;
use English;
use OpenXPKI::Server::Context qw( CTX );

requires '__get_targets_from_profile';


sub __fetch_targets {

    my $self     = shift;
    my $prefix_default = shift; # the default prefix

    my $context = $self->workflow()->context();

    my @target;
    # first of all check if there is a queue
    if ( $context->param( 'tmp_publish_queue' ) ) {
        my $queue =  $context->param( 'tmp_publish_queue' );
        ##! 16: 'Load targets from context queue'
        if (!ref $queue) {
            $queue  = OpenXPKI::Serialization::Simple->new()->deserialize( $queue );
        }

        # keep backward compatibility
        if (ref eq 'ARRAY') {
            @target = @{$queue};
        } else {
            $prefix_default = $queue->{prefix};
            @target = @{$queue->{target}};
        }
        CTX('log')->application()->info(sprintf('Reloaded %d targets from queue', scalar @target));

    # explicit prefix set in activity
    } elsif (defined $self->param('prefix')) {
        my $prefix = $self->param('prefix');
        # if the prefix is empty or does not exists we skip publishing
        if (!$prefix) {
            CTX('log')->application()->debug('Publication in prefix mode but prefix is empty');
        } elsif (CTX('config')->exists( $prefix )) {
            # split prefix to override default prefix
            $prefix_default = [ split /\./, $prefix ];
            # Get the list of targets from prefix
            @target = CTX('config')->get_keys( $prefix );
        } else {
            CTX('log')->application()->debug('Publication in prefix mode but prefix does not exist');
        }

    # explicit targets are set from outside
    } elsif (defined $self->param('target')) {
        # to enable template processing we allow scalar with spaces
        # or array ref if set by hand
        my $target = $self->param('target');
        if (!$target) {
            CTX('log')->application()->debug('Publication to explicit empty target');
        } elsif (ref $target) {
            @target = @{$target};
        } else {
            @target = split /\s+/, $target;
        }
    } else {
    # nothing set explicit so we read from the profiles
        @target = @{ $self->__get_targets_from_profile() };
    }

    if (!@target) {
        CTX('log')->application()->info('No targets found for publication');
        return;
    }

    CTX('log')->application()->debug('Targets found for publication: ' . join(",", @target));
    return ( $prefix_default, \@target );
}


sub __walk_targets {

    ##! 8: 'start'
    my $self     = shift;
    my ( $prefix, $target, $publish_key, $data, $param ) = @_;

    CTX('log')->application()->debug('Starting Publication for '. $publish_key .' to targets ' . join(",", @{$target}));

    my $on_error = $self->param('on_error') || '';
    my @failed;
    my $config = CTX('config');
    ##! 32: 'Targets ' . Dumper \@target
    foreach my $target (@{$target}) {
        # do not call set on non existing targets as this will write the value
        # into to the memory connector and return true which is hard to debug
        if (!$config->exists( [ @{$prefix}, $target ] )) {
            CTX('log')->application()->debug("Target node $target does not exist - skipping");
            next;
        }
        my $res;
        eval{ $res = $config->set( [ @{$prefix}, $target, $publish_key ], $data, $param ); };
        if (my $eval_err = $EVAL_ERROR) {
            CTX('log')->application()->debug("Publishing failed with $eval_err");
            if ($on_error eq 'queue') {
                push @failed, $target;
                CTX('log')->application()->info("Publication failed for target $target, requeuing");

            } elsif ($on_error eq 'skip') {
                CTX('log')->application()->warn("Publication failed for target $target and skip is set");

            } else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PUBLICATION_FAILED',
                    params => {
                        TARGET => $target,
                        ERROR => $eval_err
                    }
                );
            }
        } elsif (!defined $res) {
            CTX('log')->application()->warn("Entity publication to $target for ". $publish_key." returned undef");
        } else {
            CTX('log')->application()->info("Entity publication to $target for ". $publish_key." done $res " );
        }
    }

    if (@failed) {
        $self->workflow()->context()->param( 'tmp_publish_queue' => {
            target => \@failed,
            prefix => $prefix,
        });
        ##! 32: \@failed
        return  \@failed;
    }
    $self->workflow()->context()->param( { 'tmp_publish_queue' => undef });
    return;

}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Role::Publish

=head1 Description

=head1 Configuration

=head2 Parameters

=over

=item prefix

Enables publishing to a fixed set of connectors, prefix must be a
connector path pointing to a hash where the values are the connector
references to publish to.

=item target

Enables publishing to a fixed set of connectors, must hold the names of
connectors that exist at the default prefix (e.g. publishing.entity).
These are the same words as used in the profile definitions.
Accepts either multiple names separated by space or an array ref.

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
