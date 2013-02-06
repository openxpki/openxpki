# OpenXPKI::Server::Workflow::Condition::SCEPv2::ValidSCEPTID
# Written by Scott Hardin for the OpenXPKI Project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::SCEPv2::ValidSCEPTID;

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SCEPv2::ValidSCEPTID

=head1 SYNOPSIS

    <action name="do_something">
        <condition name="scep_tid_ok"
            class="OpenXPKI::Server::Workflow::Condition::SCEPv2::ValidSCEPTID">
        </condition>
    </action>

=head1 DESCRIPTION

This condition checks whether the SCEP Transaction ID is valid. It is considered
valid if the string length is at least 32 chars and consists only of hex digits.

=cut

use strict;
use warnings;

use base qw( Workflow::Condition );

#use Workflow::Exception qw( condition_error configuration_error );
#use OpenXPKI::Server::Context qw( CTX );
#use OpenXPKI::Debug;
use OpenXPKI::Exception;
use English;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context = $workflow->context();

    my $scep_tid = $context->param('scep_tid');
    ##! 64: 'scep_tid: ' . $scep_tid

    if (   defined $scep_tid
        && length($scep_tid) >= 32
        && $scep_tid =~ m/^[0-9a-fA-F]+$/ )
    {
        return 1;
    }

    OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENT_INVALID_TID',
            params => {
                SCEP_TID => (defined $scep_tid ? $scep_tid : '<undef>'),
                SCEP_TIT_LEN => length($scep_tid),
            }
    );

}

1;
