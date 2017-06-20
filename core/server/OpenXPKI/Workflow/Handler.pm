package OpenXPKI::Workflow::Handler;

=head1 NAME

OpenXPKI::Workflow::Handler - Workflow factory manager

=head1 DESCRIPTION

Handler class that manages the workflow factories for the different realms
and configuration states. The class is created on server init and stored
in the context as workflow_handler. It always creates one factory using the
workflow definitions from the current head version for each realm. You can
specify additional instances that should be created to the constructor.

=cut

use Moose;
use English;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Workflow::Factory;
use OpenXPKI::Workflow::Config;
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

has '_cache' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {}; }
);

=head2 load_default_factories

Loads the most current workflow definiton for each realm.

=cut
sub load_default_factories {
    my $self = shift;
    ##! 1: 'start'
    my @realms = CTX('config')->get_keys('system.realms');
    foreach my $realm (@realms) {
        ##! 8: 'load realm $realm'
        $self->_cache->{$realm} = undef;
        CTX('session')->data->pki_realm( $realm );
        $self->get_factory();
    }
}

=head2 get_workflow { ID }

This is a shortcut method that expects only a workflow id and will take care
of finding the correct version and workflow type and returns an instance of
OpenXPKI::Workflow.

=cut
sub get_workflow {
    my ($self, $args) = @_;

    my $wf_id = $args->{ID};

    # Fetch the workflow details from the workflow table
    ##! 16: 'determine factory for workflow ' . $wf_id
    my $wf = CTX('dbi')->select_one(
        from => 'workflow',
        columns => [ qw( workflow_type pki_realm ) ],
        where => { workflow_id => $wf_id },
    );
    if (! defined $wf) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_WORKFLOW_HANDLER_ID_NOT_FOUND',
            params  => {
                WORKFLOW_ID => $wf_id,
            },
        );
    }

    # We can not load workflows from other realms as this will break config and security
    # The watchdog switches the session realm before instantiating a new factory
    if (CTX('session')->data->pki_realm ne $wf->{pki_realm}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_WORKFLOW_HANDLER_NOT_IN_CURRENT_REALM',
            params  => {
                WORKFLOW_ID => $wf_id,
                WORKFLOW_REALM => $wf->{pki_realm},
                SESSION_REALM => CTX('session')->data->pki_realm
            },
        );
    }

    # We have now obtained the configuration id that was active during
    # creation of the workflow instance. However, if for some reason
    # the matching configuration is not available we have two options:
    # 1. bail out with an error
    # 2. accept that there is an error and continue anyway with a different
    #    configuration
    # Option 1 is not ideal: if the corresponding configuration has for
    # some reason be deleted from the database the workflow cannot be
    # instantiated any longer. This is often not really a problem but
    # sometimes this will lead to severe problems, e. g. for long
    # running workflows. unfortunately, if a workflow cannot be instantiated
    # it can neither be displayed, nor executed.
    # In order to make things a bit more robust fall back to using a newer
    # configuration than the one missing. As we don't have a timestamp
    # for the configuration, a safe bet is to use the current configuration.
    # Caveat: the current workflow definition might not be compatible with
    # the particular workflow instance. There is a risk that the workflow
    # instance gets stuck in an unreachable state.
    # In comparison to not being able to even view the workflow this seems
    # to be an acceptable tradeoff.

    my $factory = $self->get_factory;

    ##! 64: 'factory: ' . Dumper $factory
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_FACTORY_NOT_DEFINED',
        );
    }

    return $factory->fetch_workflow( $wf->{'workflow_type'}, $wf_id );
}

=head2 get_factory( VERSION, FALLBACK )

Return a workflow factory using the versioned config.

=over

=item VERSION The config version hash to use

=item FALLBACK 0|1 weather to fallback to current if version is not found

=back

=cut
sub get_factory {
    my ($self, $args) = @_;

    ##! 1: 'start'
    ##! 16: Dumper $args

    my $pki_realm = CTX('session')->data->pki_realm;
    # Check if we already have that factory in the cache
    if (defined $self->_cache->{ $pki_realm } ) {
        return $self->_cache->{ $pki_realm };
    }

    # Fetch the serialized Workflow definition from the config layer
    my $conn = CTX('config');

    if (!$conn->exists('workflow.def')) {
         OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_FACTORY_NO_CONFIG_FOUND',
        );
    }

    my $yaml_config = OpenXPKI::Workflow::Config->new()->workflow_config();

    my $workflow_factory = OpenXPKI::Workflow::Factory->new();
    $workflow_factory->add_config( %{$yaml_config} );

    ##! 32: Dumper $workflow_factory

    $self->_cache->{ $pki_realm } = $workflow_factory;

    return $workflow_factory;
}

1;

__END__
