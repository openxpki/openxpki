# OpenXPKI::Server::Workflow::Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Rewritten by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2005-2007 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Activity;

use strict;
use base qw( Workflow::Action );

use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

use Workflow::Exception qw( workflow_error );
use Data::Dumper;

__PACKAGE__->mk_accessors( 'resulting_state' );

sub init {
    my ( $self, $wf, $params ) = @_;
    ##! 1: 'start'
    ##! 64: 'self: ' . Dumper $self
    ##! 64: 'params: ' . Dumper $params
    ##! 64: 'wf: ' . Dumper $wf

    # FIXME - this is a bit of a hack - we're peeking into Workflow's
    # internal structures here. Workflow should provide a way to get
    # the resulting state for an activity itself.
    $self->resulting_state($wf->{_states}->{$wf->state()}->{_actions}->{$params->{name}}->{resulting_state});

    ##! 16: 'resulting_state: ' . $self->resulting_state()
    $self->{PKI_REALM} = CTX('session')->get_pki_realm();
    ##! 16: 'self->{PKI_REALM} = ' . $self->{PKI_REALM}

    # determine workflow's config ID
    $self->{CONFIG_ID} = CTX('api')->get_config_id({ ID => $wf->id() });
    ##! 16: 'self->{CONFIG_ID} = ' . $self->{CONFIG_ID}

    # call Workflow::Action's init()
    $self->SUPER::init($wf, $params);

    ##! 1: 'end'
    return 1;
}

sub get_xpath {
    my $self = shift;
    ##! 1: 'start, proxying to xml_config with config ID: ' . $self->{CONFIG_ID}
    return CTX('xml_config')->get_xpath(
        @_,
        CONFIG_ID => $self->config_id(),
    );
}

sub get_xpath_count {
    my $self = shift;
    ##! 1: 'start, proxying to xml_config with config ID: ' . $self->{CONFIG_ID}
    return CTX('xml_config')->get_xpath_count(
        @_,
        CONFIG_ID => $self->config_id(),
    );
}

sub config_id {
    my $self = shift;

    if (defined $self->{CONFIG_ID}) {
        return $self->{CONFIG_ID};
    }
    else {
        # this (only) happens when the activity is called as the first
        # activity in the workflow ...
        # as the config_id is only written to the context once the workflow
        # has been created (which is technically not the case while the
        # first activity is still running), we need to get the current
        # config ID, which will be the workflow's config ID anyways ...
        return CTX('api')->get_current_config_id();
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity

=head1 Description

Base class for OpenXPKI Activities. Deriving from this class is
not mandatory, this class only provides some helper functions that
make Activity implementation easier.

=head1 Functions

=head2 init

Is called during the creation of the activity class. Initializes
$self->{CONFIG_ID}, which is the config ID of the workflow.
Also sets $self->{PKI_REALM} to CTX('session')->get_pki_realm()

=head2 get_xpath

Calls CTX('xml_config')->get_xpath() with the workflow's config ID.

=head2 config_id

Returns the config identifier for the workflow or the current config
identifier if the config ID is not yet set (this happens in the very
first workflow activity)
