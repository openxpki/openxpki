package OpenXPKI::Server::Workflow::Validator::ValidityWindow;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Serialization::Simple;

__PACKAGE__->mk_accessors(qw(error));

sub _init {
    my ( $self, $params ) = @_;
    $self->error( 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_FAILED' );
    $self->error( $params->{error} ) if ($params->{error});
}

sub validate {
    my ( $self, $wf, $notbefore, $notafter ) = @_;

    ##! 1: 'start'

    my @errors;

    if ($notbefore && $notbefore !~ m{ \A \d+ \z }xs) {
        push @errors, 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_INVALID_NOTBEFORE';
    }

    if ($notafter && $notafter !~ m{ \A \d+ \z }xs) {
        push @errors, 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_INVALID_NOTAFTER';
    }

    if ($notafter) {
        if ($notbefore && $notafter == $notbefore) {
            push @errors, 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_NOTAFTER_EQUAL_TO_NOTBEFORE';
        }

        if ($notbefore && $notafter < $notbefore) {
            push @errors, 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_NOTAFTER_EARLIER_THAN_NOTBEFORE';
        }

        if ($notafter < time()) {
            push @errors, 'I18N_OPENXPKI_UI_ERROR_VALIDATOR_VALIDITY_TIME_NOTAFTER_IN_THE_PAST';
        }
    }

    if (@errors) {
        # Need to implement this in New UI first
        #$wf->context()->param( '__error' => [ $self->error(), { FIELD => $field, VALUES => \@errors }]);
        ##! 32: 'Regex errors on field ' . $field . ', values '  . Dumper \@errors
        CTX('log')->application()->error("Validity window validator failed ");

        validation_error( sprintf "%s (%s)", $self->error(), join(" / ", @errors) );
        return 0;
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ValidityWindow

=head1 SYNOPSIS

  global_validity_window
  param:
    error: Error message
  arg:
    - $notbefore

=head1 DESCRIPTION

Validates a given notbefore/notafter date pair. It first checks both values
to be a proper unix timestamp (or empty). Second, it checks if notafter > now
and notafter > notbefore. Setting notbefore in the past is supported!

The validator definition can have a custom error parameter.