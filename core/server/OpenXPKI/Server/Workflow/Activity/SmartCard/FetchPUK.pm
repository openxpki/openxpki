# OpenXPKI::Server::Workflow::Activity::SmartCard::FetchPUK
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::FetchPUK;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self = shift;
    my $workflow = shift;
    my $valparam = $self->param('ds_value_param');
    ##! 16: 'ds_value_param: ' . $valparam

    $self->SUPER::execute($workflow);

    my $context = $workflow->context();

    my $value = $context->param($valparam);

    ##! 32: 'token_id: ' . Dumper($context->param('token_id'));
    ##! 32: 'value: ' . Dumper($value);

    CTX('log')->application()->info('SmartCard fetching puk from datapool for ' . $context->param('token_id'));

    CTX('log')->audit('application')->info('fetching smartcard puk from datapool', {
        sctoken_id => $context->param('token_id')
    });

    my $ser = OpenXPKI::Serialization::Simple->new();
    # autodetect serialized arrays
    if (OpenXPKI::Serialization::Simple::is_serialized($value)) {
        $value = $ser->deserialize($value);
    } else {
    # coerce returned value into an array. the parent implementation
    # does not care about the PUK handling at all, but on this level
    # we do know that we are dealing with PUKs. hence it is
    # safe to assume that the caller wants an array...
    $value = [ $value ];
    }

    $value = $ser->serialize($value);

    $context->param($valparam => $value);

    return 1;
}

1;

__END__

=head1 Name OpenXPKI::Server::Workflow::Activity::SmartCard::FetchPUK

=head1 Description

This fetches the currently-known PUKs from the datastore. If one entry is
returned, it is the current PUK on the card. If two are returned, it is
probable that the first is a new PUK to be written and the second is the
current PUK. Note to client: the returned string is probably a serialized
array, so the client needs to deserialize it before using it. Suggested
behavior of client: if more than one PUK is returned, try to change the PUK
to the first in the list using the second. On fail, the first is most likely
the correct PUK, on success, the first PUK is now correct.



See OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry

