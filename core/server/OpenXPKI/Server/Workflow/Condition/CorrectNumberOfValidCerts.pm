# OpenXPKI::Server::Workflow::Condition::CorrectNumberOfValidCerts.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::CorrectNumberOfValidCerts;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;
use English;

use Data::Dumper;

__PACKAGE__->mk_accessors( 'min' );
__PACKAGE__->mk_accessors( 'max' );

sub _init
{
    my ( $self, $params ) = @_;
    if (exists $params->{min}) {
        $self->min($params->{min});
    }
    if (exists $params->{max}) {
        $self->max($params->{max});
    }
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();

    my $valid_certs = $context->param('current_valid_certificates');
    ##! 16: 'min: ' . $self->min()
    ##! 16: 'valid certs: ' . $valid_certs
    ##! 16: 'max: ' . $self->max()

    if ($valid_certs < $self->min() || $valid_certs > $self->max()) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTNUMBEROFVALIDCERTS_INCORRECT_NUMBER_OF_VALID_CERTS');
    }
    ##! 16: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CorrectNumberOfValidCerts

=head1 SYNOPSIS

<action name="do_something">
  <condition name="correct_number_of_valid_certs"
             class="OpenXPKI::Server::Workflow::Condition::CorrectNumberOfValidCerts">
    <param name="min" value="1"/>
    <param name="max" value="2"/>
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if a renewal SCEP request has the correct number
of currently valid certificates. The definition of "correct" can be
tweaked by setting the condition parameters min and max.
