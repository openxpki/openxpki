# OpenXPKI::Server::Workflow::Condition::MoreCertsToTest.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::MoreCertsToTest;

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
    my $nr_of_certs = $context->param('nr_of_certs');
    my $certs_installed = $context->param('certs_installed');
    ##! 16: 'nr_of_certs: ' . $nr_of_certs
    ##! 16: 'certs_installed: ' . $certs_installed
    if ($certs_installed == $nr_of_certs) {
        ##! 32: 'enough certs -> ERROR'
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_MORECERTSTOTEST_NO_MORE_CERTS_TO_TEST');
    }
   return 1; 
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::MoreCertsToTest

=head1 SYNOPSIS

<action name="do_something">
  <condition name="more_certs_to_test"
             class="OpenXPKI::Server::Workflow::Condition::MoreCertsToTest">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if more certificate test results are to be checked or if all issued
certificates have been tested.
If the magic condition name 'no_more_certs_to_test' is used,
it returns just the opposite.
