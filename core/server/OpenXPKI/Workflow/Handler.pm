# OpenXPKI::Workflow::Handler
#
# Written 2012 by Oliver Welter for the OpenXPKI project
# Copyright (C) 2012 by The OpenXPKI Project
#
#
=head1 OpenXPKI::Workflow::Handler

Handler class that manages the workflow factories for the different realms
and configuration states. The class is created on server init and stored
in the context as workflow_handler. It always creates one factory using the
workflow definitions from the current head version for each realm. You can
specify additional instances that should be created to the constructor.

=cut

package OpenXPKI::Workflow::Handler;

use strict;
use warnings;
use English;
use Moose;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Workflow::Factory;
use OpenXPKI::Workflow::Config;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;

has '_cache' => (
    is => 'rw',
    isa => 'HashRef',
    required => 0,
    default => sub { return {}; }
);
 

sub BUILD {
    my $self = shift;
    my $args = shift;

}

=head2 load_default_factories

Loads the most current workflow definiton for each realm.

=cut
sub load_default_factories {
    ##! 1: 'start'
    my $self = shift;
    my @realms = CTX('config')->get_keys('system.realms');
    foreach my $realm (@realms) {
        ##! 8: 'load realm $realm'
        $self->_cache->{$realm} = undef;
        CTX('session')->set_pki_realm( $realm );
        $self->get_factory();
    }
}

=head2 get_workflow { ID }

This is a shortcut method that expects only a workflow id and will take care
of finding the correct version and workflow type and returns an instance of
OpenXPKI::Workflow.

=cut
sub get_workflow {

    my $self = shift;
    my $args = shift;

    my $wf_id = $args->{ID};

    # Due to the mysql transaction model we MUST make a commit to refresh the view
    # on the database as we can have parallel process on the same workflow!
    CTX('dbi_workflow')->commit();

    # Fetch the workflow details from the workflow table
    ##! 16: 'determine factory for workflow ' . $arg_ref->{WORKFLOW_ID}
    my $wf = CTX('dbi_workflow')->first(
        TABLE   => 'WORKFLOW',
        KEY => $wf_id
    );
    if (! defined $wf) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFO',
            params  => {
                WORKFLOW_ID => $wf_id,
            },
        );
    }

    # We can not load workflows from other realms as this will break config and security
    # The watchdog switches the session realm before instantiating a new factory
    if (CTX('session')->get_pki_realm() ne $wf->{PKI_REALM}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_REALM_MISSMATCH',
            params  => {
                WORKFLOW_ID => $wf_id,
                WORKFLOW_REALM => $wf->{PKI_REALM},
                SESSION_REALM => CTX('session')->get_pki_realm()
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

    my $factory = $self->get_factory();

    ##! 64: 'factory: ' . Dumper $factory
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_FACTORY_NOT_DEFINED',
        );
    }

    my $workflow = $factory->fetch_workflow( $wf->{'WORKFLOW_TYPE'}, $wf_id );

    return $workflow;

}

=head2 get_factory( VERSION, FALLBACK )

Return a workflow factory using the versioned config.

=over

=item VERSION The config version hash to use

=item FALLBACK 0|1 weather to fallback to current if version is not found

=back

=cut
sub get_factory {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;

    ##! 16: Dumper $args
  
    my $pki_realm = CTX('session')->get_pki_realm();
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
