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
use OpenXPKI::XML::Cache;
use Data::Dumper;

has '_cache' => (
    is => 'rw',
    isa => 'HashRef',
    required => 0,
    default => sub { return {}; }
);

#has '_workflow_config' => (
#    is => 'ro',
#    isa => 'HashRef',
#    builder => '_init_workflow_config',
#);

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
        $self->_cache->{$realm} = {};
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

    my $wf_session_info = CTX('session')->parse_serialized_info($wf->{WORKFLOW_SESSION});
    if (!$wf_session_info || ref $wf_session_info ne 'HASH' || !$wf_session_info->{config_version}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_UNABLE_TO_PARSE_WORKFLOW_INFO',
            params  => {
                WORKFLOW_ID => $wf_id,
                WORKFLOW_SESSION => $wf->{WORKFLOW_SESSION}
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

    my $factory = $self->get_factory({
        VERSION => $wf_session_info->{config_version}, FALLBACK => 1
    });

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

=item VERSION The config version hash to use

=item FALLBACK 0|1 weather to fallback to current if version is not found

=cut
sub get_factory {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;

    ##! 16: Dumper $args

    # Testing and special purpose shortcut - get an unregistered factory from an existing xml config
    if ($args->{XML_CONFIG}) {
        OpenXPKI::Exception->throw('message' => 'Workflow XML Format is no longer supported');
    }

    # TODO - put in config versioning and caching from old xml factory
=cut

    # Prepare version switch if necessary
    my $oldversion;
    my $version = CTX('session')->get_config_version();
    if ( $args->{VERSION} && $args->{VERSION} ne $version ) {
        $oldversion = $version;
        $version = $args->{VERSION};
    }

    my $pki_realm = CTX('session')->get_pki_realm();
    ##! 16: "Probing realm $pki_realm version $version"
    # Check if we already have that factory in the cache
    if ($self->_cache->{ $pki_realm }->{ $version }) {
        return $self->_cache->{ $pki_realm }->{ $version };
    }

    # Not found - if necessary make the session show the expected version
    CTX('session')->set_config_version( $version ) if ($oldversion);

    # Fetch the serialized Workflow definition from the config layer
    my $workflow_serialized_config = CTX('config')->get('workflow');

    # Set back the version, its no longer needed
    # Must be done before exception as we stick with the old version otherwise!
    CTX('session')->set_config_version( $oldversion ) if ($oldversion);

    # There might be cases where we request unknown config version
    # TODO Implement fall back to current version - if requested
    if (!$workflow_serialized_config) {
         OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_FACTORY_UNKNOWN_VERSION_REQUESTED',
            params => {
                PKI_REALM => $pki_realm,
                VERSION => $args->{VERSION}
            }
        );
    }

    my $xml_config = OpenXPKI::XML::Cache->new( SERIALIZED_CACHE => $workflow_serialized_config );

    my $factory = OpenXPKI::Workflow::Handler::__get_instance ({
        XML_CONFIG => $xml_config,
        WF_CONFIG_MAP => $self->_workflow_config(),
        FAKE_MISSING_CLASSES => 1
    });
    $self->_cache->{ $pki_realm }->{ $version } = $factory;
=cut

    my $wf_config = OpenXPKI::Workflow::Config->new();
    my $config = $wf_config->workflow_config();

    ##! 16: Dumper $config

    my $workflow_factory = OpenXPKI::Workflow::Factory->new();
    $workflow_factory->add_config( %{$config} );

    #! 16: Dumper $workflow_factory

    return $workflow_factory;

}






1;

__END__
