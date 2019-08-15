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
use Workflow::Exception qw(configuration_error workflow_error);

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $pki_realm  = CTX('api2')->get_pki_realm();
    my $context   = $workflow->context();
    my $target_key = $self->param('target_key') || 'token_alias_list';

    my $config = CTX('config');

    my $group_name;

    # get group name from type
    if ($self->param('token')) {
        # Determine the name of the key group for cert signing
        $group_name = $config->get(['crypto','type', $self->param('token') ]);
        if (!$group_name) {
            workflow_error( "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_LIST_ACTIVE_TOKEN_NO_GROUP_FOUND_FOR_TYPE",
                     { TOKEN => $self->param('token') } );
        }

    # explicit group name
    } elsif ($self->param('group')) {
        $group_name = $self->param('group');

    # oops
    } else {
        configuration_error( 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_LIST_ACTIVE_TOKEN_NO_GROUP_OR_TYPE_GIVEN' );
    }

    my $token_list = CTX('api2')->list_active_aliases( group => $group_name );

    if (!@{$token_list} && !$self->param('empty_ok')) {
        workflow_error(
            "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_LIST_ACTIVE_TOKEN_DID_NOT_FIND_ANY_TOKEN",
            { GROUP => $group_name }
        );
    }

    ##! 32: "Active tokens found " . Dumper $token_list
    my @token_alias_list = map { $_->{alias} } @{$token_list};

    $context->param( $target_key  => \@token_alias_list );

    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ListActiveToken

=head1 Description

Load the alias names of all active tokens in the given token group (parameter
I<group>) or with the given token type (paramater I<token>).
The list of token names will be in the context with key token_alias_list
as array, sorted by notbefore data, most current first. The target
key can be set using the target_key parameter

The class will throw an exception if no items are found unless the "empty_ok"
parameter is set to a true value.

=head1 Configuration

=head2 Activity parameters

=over

=item token

Name of the token type to look up, e.g. certsign

=item group

Name of the group to look up, e.g. ca-signer

token and group are mutually exclusive, token has precedence.

=item target_key

Context item to write the result to

=item empty_ok

Boolean, if true does not throw an error if the token list is empty.

=back
