package OpenXPKI::Client::Service::Role::PickupWorkflow;
use Moose::Role;

use English;
use Data::Dumper;

sub pickup_workflow {

    my $self = shift;
    # the hash from the config section of this method
    my $config = shift;
    my $pickup_value = shift;

    my $workflow_type = $config->{workflow};
    my $client = $self->backend();
    my $wf_id;
    if (my $wf_type = $config->{pickup_workflow}) {

        $self->logger()->debug("Pickup via workflow $wf_type with keys " . join(",", keys %{$pickup_value}));
        my $result = $client->handle_workflow({
            type => $wf_type,
            params => $pickup_value,
        });

        die "No result from pickup workflow" unless($result->{context});
        $self->logger()->trace("Pickup workflow result: " . Dumper $result) if ($self->logger()->is_trace);

        $wf_id = $result->{context}->{workflow_id};

    } elsif ($config->{pickup_namespace}) {

        $self->logger()->debug("Pickup via datapool with $config->{pickup_namespace} => $pickup_value" );
        my $wfl = $client->run_command('get_data_pool_entry', {
            namespace => $config->{pickup_namespace},
            key => $pickup_value,
        });
        if ($wfl->{value}) {
            $wf_id = $wfl->{value};
        }

    } else {
        # pickup from workflow with explicit attribute name or key name
        my $pickup_key = $config->{pickup_attribute} || $config->{pickup};

        $self->logger()->debug("Pickup via attribute with $pickup_key => $pickup_value" );
        my $wfl = $client->run_command('search_workflow_instances', {
            type => $workflow_type,
            attribute => { $pickup_key => $pickup_value },
            limit => 2
        });

        if (@$wfl > 1) {
            die "Unable to pickup workflow - ambigous search result";
        } elsif (@$wfl == 1) {
            $wf_id = $wfl->[0]->{workflow_id};
        }
    }

    if (!$wf_id) {
        $self->logger()->trace("No pickup as no result found");
        return unless ($wf_id);
    }

    if (ref $wf_id || $wf_id !~ m{\A\d+\z}) {
        $self->logger()->error("Pickup result is not an integer number!");
        $self->logger()->trace(Dumper $wf_id) if ($self->logger()->is_trace());
        return;
    }

    $self->logger()->debug("Pickup $wf_id for " . (ref $pickup_value ? (join " ,", values %{$pickup_value}) : $pickup_value));
    return $client->handle_workflow({
        id => $wf_id,
    });

}

1;

__END__