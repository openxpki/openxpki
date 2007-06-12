# OpenXPKI::Server::Workflow::Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Rewritten by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2005-2007 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Activity;

use strict;
use base qw( Workflow::Action );

use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

use Workflow::Exception qw( workflow_error );

sub init {
    my ( $self, $wf, $params ) = @_;
    ##! 1: 'start'

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
        CONFIG_ID => $self->{CONFIG_ID},
    );
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
