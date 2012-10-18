# OpenXPKI::Server::Workflow::Condition::CheckCertTestResult.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::CheckCertTestResult;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;


sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context    = $workflow->context();
    my $testresult = $context->param('testresult'); 

    if ($testresult ne 'true') {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKCERTTESTRESULT_TESTRESULT_NOT_TRUE');
    }
    ##! 16: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CheckCertTestResult

=head1 SYNOPSIS

<action name="do_something">
  <condition name="test_result_ok"
             class="OpenXPKI::Server::Workflow::Condition::CheckCertTestResult">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the client side certificate installation
test in the smartcard personalization workflow has succeeded.
Currently, it only checks if the context parameter 'testresult'
is 'true'. More complicated tests checking signatures or decryptions
could possibly be added.
If the condition name is 'test_result_failed', the condition
checks the opposite.
