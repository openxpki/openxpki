package OpenXPKI::Workflow::Handler;

use Moose;

=head1 NAME

OpenXPKI::Workflow::Handler - Workflow factory manager

=head1 DESCRIPTION

Handler class that manages the workflow factories for the different realms
and configuration states. The class is created on server init and stored
in the context as workflow_handler. It always creates one factory using the
workflow definitions from the current head version for each realm. You can
specify additional instances that should be created to the constructor.

=cut

use English;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Workflow::Factory;
use OpenXPKI::Workflow::Config;
use OpenXPKI::Exception;
use OpenXPKI::Debug;


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
    ##! 1: 'start'

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

    my $factory = $self->get_factory;

    ##! 64: 'factory: ' . Dumper $factory
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_FACTORY_NOT_DEFINED',
        );
    }

    return $factory->fetch_workflow( $wf->{'workflow_type'}, $wf_id );
}

=head2 get_factory

Return a workflow factory using the versioned config.

=cut
sub get_factory {
    my ($self) = @_;
    ##! 1: 'start'


    my $pki_realm = CTX('session')->data->pki_realm;

    # Check if we already have that factory in the cache
    if (defined $self->_cache->{ $pki_realm } ) {
        return $self->_cache->{ $pki_realm };
    }

    my $config = OpenXPKI::Workflow::Config->new()->workflow_config();

    my $workflow_factory = OpenXPKI::Workflow::Factory->new();
    $workflow_factory->add_config( %{$config} );

    ##! 32: Dumper $workflow_factory

    $self->_cache->{ $pki_realm } = $workflow_factory;

    return $workflow_factory;
}

__PACKAGE__->meta->make_immutable;

__END__
