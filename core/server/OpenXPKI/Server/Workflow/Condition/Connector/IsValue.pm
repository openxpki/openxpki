# OpenXPKI::Server::Workflow::Condition::Connector::IsValue
# Written by Oliver Welter for the OpenXPKI Project 2012
# Copyright (c) 2012 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::Connector::IsValue;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;
use OpenXPKI::Debug;

sub _evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context = $workflow->context();

    my $path = $self->param('config_path');
    my $delimiter = $self->param('delimiter') || '\.';

    if ($delimiter eq '.') { $delimiter = '\.'; }

    my @path = split $delimiter, $path;

    ##! 16: 'Delimiter: '.$delimiter.', Plain Path ' . $path
    ##! 16: 'Path splitted ' . Dumper \@path

    my $value = CTX('config')->get( \@path );

    my $expected = $self->param('value');

    CTX('log')->application()->debug("Check IsValue '$value' != '$expected'");


    if ($value != $expected ) {
        ##! 16: " Values differ - expected: $expected, found: $value "
        condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CONNECTOR_IS_VALUE");
    }
    ##! 32: sprintf ' Values match - expected: %s, found: %s ', $expected , $value
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Connector::IsValue

=head1 SYNOPSIS

    config_path: path|of|the|node.with.dots
    delimiter: |
    value: checkme


=head1 DESCRIPTION

This condition looks up the value at config_path from the connector and
checks weather the returned value is equal to the given value.

