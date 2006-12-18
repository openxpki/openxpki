# OpenXPKI::Server::Workflow::Condition::ApprovalNeeded.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Condition::ApprovalNeeded;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug 'OpenXPKI::Server::API::Workflow::Condition::ApprovalNeeded';
use English;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_APPROVALNEEDED_NO_APPROVAL_NEEDED');

   return 1; 
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::ApprovalNeeded

=head1 SYNOPSIS

<action name="do_something">
  <condition name="approval_needed"
             class="OpenXPKI::Server::Workflow::Condition::ApprovalNeeded">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if approval is needed for certificates.
Currently, it just defines that no approval is needed whatsoever.
If you need approval (maybe depending on some condition or other),
you have to implement it yourself.
