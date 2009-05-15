# OpenXPKI::Server::Workflow::Condition::SCEPClientEnrollment.pm
# Written by Alexander Klink for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::SCEPClientEnrollment;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();

    my $type = $context->param('scep_client_type');
    ##! 16: 'type: ' . $type

    if ($type ne 'enrollment') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEP_CLIENT_ENROLLMENT_NO_ENROLLMENT',
        );
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SCEPClientEnrollment

=head1 SYNOPSIS

<action name="do_something">
  <condition name="scep_client_enrollment"
             class="OpenXPKI::Server::Workflow::Condition::SCEPClientEnrollment">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether an SCEP request is a SCEP Client request
with enrollment type (i.e. it needs approval before the certificate is
issued). It does so by looking at the 'scep_client_type' context parameter,
which is set by the SCEPClient condition.
