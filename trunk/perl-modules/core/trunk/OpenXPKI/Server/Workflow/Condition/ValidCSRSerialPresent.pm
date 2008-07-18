# OpenXPKI::Server::Workflow::Condition::ValidCSRSerialPresent.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::ValidCSRSerialPresent;

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

    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)

    my $csr_serial = $context->param('csr_serial');

    if (! defined $csr_serial) {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_VALIDCSRSERIALPRESENT_NO_CSR_SERIAL_PRESENT');
    }
    # get a fresh view of the database
    CTX('dbi_backend')->commit();

    my $csr = CTX('dbi_backend')->first(
        TABLE   => 'CSR',
        DYNAMIC => {
            'CSR_SERIAL' => $csr_serial,
        },
    );
    if (! defined $csr) {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_VALIDCSRSERIALPRESENT_CSR_SERIAL_FROM_CONTEXT_NOT_IN_DATABASE');
    }

   return 1; 
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::ValidCSRSerialPresent

=head1 SYNOPSIS

<action name="do_something">
  <condition name="valid_csr_serial_present">
             class="OpenXPKI::Server::Workflow::Condition::ValidCSRSerialPresent">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether a valid CSR serial is present in the
workflow context param 'csr_serial'.
