# OpenXPKI::Server::Workflow::Condition::MoreCSRsToCreate.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::MoreCSRsToCreate;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    ##! 16: 'my condition name: ' . $self->name()
    my $context  = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my @cert_issuance_data = @{ $serializer->deserialize(
        $context->param('cert_issuance_data')
    ) };
    ##! 16: 'cert_issuance_data: ' . Dumper(\@cert_issuance_data)
    my $nr_of_certs = $context->param('nr_of_certs');
    ##! 16: 'scalar @cert_issuance_data: ' . scalar @cert_issuance_data
    ##! 16: 'nr_of_certs: ' . $nr_of_certs

    if (scalar @cert_issuance_data == $nr_of_certs) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_MORECSRSTOCREATE_NO_MORE_CSRS_TO_CREATE');
    }
    return 1; 
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::MoreCSRsToCreate

=head1 SYNOPSIS

<action name="do_something">
  <condition name="more_csrs_to_create"
             class="OpenXPKI::Server::Workflow::Condition::MoreCSRsToCreate">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if more CSRs are to be created by checking the
size of the cert_issuance_data array against the nr_of_certificates
scalar in the workflow context.
