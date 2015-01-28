# OpenXPKI::Server::Workflow::Activity::Tools::ListActiveToken
# Copyright (c) 2015 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::ListActiveToken;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

use OpenXPKI::Server::Workflow::WFObject::WFArray;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $context   = $workflow->context();

    my $config = CTX('config');

    my $token_alias_list = OpenXPKI::Server::Workflow::WFObject::WFArray->new({
        workflow => $workflow,
        context_key => 'token_alias_list',
    });

    my $token_list;
    my $group_name;

    # get group name from type
    if ($self->param('token')) {
        # Determine the name of the key group for cert signing
        $group_name = $config->get(['crypto','type', $self->param('token') ]);
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_LIST_ACTIVE_TOKEN_NO_GROUP_FOUND_FOR_TYPE",
            params => { TOKEN => $self->param('token') }
        ) unless ($group_name);

    # explicit group name
    } elsif ($self->param('group')) {
        $group_name = $self->param('group');

    # oops
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_LIST_ACTIVE_TOKEN_NO_GROUP_OR_TYPE_GIVEN",
        );
    }

    my $token_list = CTX('api')->list_active_aliases( { GROUP => $group_name } );

    if (!@{$token_list} && !$self->param('empty_ok')) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_LIST_ACTIVE_TOKEN_DID_NOT_FIND_ANY_TOKEN",
            params => { GROUP => $group_name }
        );
    }

    ##! 32: "Active tokens found " . Dumper $token_list
    foreach my $alias (@{$token_list}) {
        $token_alias_list->push($alias->{ALIAS});
    }

    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ListActiveToken

=head1 Description

Load the alias names of all active tokens in the given token group (parameter
I<group>) or with the given token type (paramater I<token>).
The list of token names will be in the context with key token_alias_list as
array, sorted by notbefore data, most current first.

The class will throw an exception if no items are found unless the "empty_ok"
parameter is set to a true value.
