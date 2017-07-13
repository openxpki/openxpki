package OpenXPKI::Server::Workflow::Validator::ValidityString;

use strict;
use warnings;

use Moose;

use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use Workflow::Exception qw( validation_error configuration_error );

extends 'OpenXPKI::Server::Workflow::Validator';

sub _validate {

    ##! 1: 'start'

    my ( $self, $wf, $timestamp ) = @_;

    ##! 16: 'timestamp ' . $timestamp

    if (!$timestamp) {
        return 1;
    }

    my $condition = $self->param('condition') || '';

    ##! 16: 'condition ' . $condition

    my $time = OpenXPKI::DateTime::get_validity({
        VALIDITY => $timestamp,
        VALIDITYFORMAT => ( $self->param('format') || 'detect' ),
    })->epoch();


    my $valid = 0;
    if ($condition eq '') {
        $valid = 1;
    } else {
        my $now = time();
        ##! 16: 'now: ' . $now
        if ($condition eq 'lt') {
            $valid = ( $time < $now );
        } elsif ($condition eq 'lte') {
            $valid = ( $time <= $now );
        } elsif ($condition eq 'gt') {
            $valid = ( $time > $now );
        } elsif ($condition eq 'gte') {
            $valid = ( $time >= $now );
        } else {
            configuration_error('Invalid condition given in Validator::ValidityString');
        }
    }

    if (!$valid) {
        validation_error( $self->param('error') || 'I18N_OPENXPKI_UI_VALIDATOR_VALIDITY_STRING_FAILED' );
    }


    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ValidityString

=head1 SYNOPSIS

  action:
      class: OpenXPKI::Server::Workflow::Validator::ValidityString
  param:
      format: detect
      condition: lte
  arg:
    - $timestamp

=head1 DESCRIPTION

This validator checks whether a given timestamp can be handled by
OpenXPKI::Datetime::get_validity. In addition, it can test if the result
is in the past/future.

=head2 Validator Parameters

=over

=item format

Any format which is accepted as VALIDITYFORMAT by
OpenXPKI::Datetime::get_validity. The default is 'detect';

=item condition

Optional, if set the resulting timestamp is checked using the equotation
I<$timestamp $condition time()>, e.g. "lte" will accepts timestamps in
the past including now.

=over

=item lt (less than)

=item lte (less than or equal)

=item gt (greater than)

=item gte (greater than or equal)

=back

=back
