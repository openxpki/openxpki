package OpenXPKI::Server::Workflow::Condition::WFArray;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Debug;
use English;

my @parameters = qw(
    array_name
    condition
    value
    error
);

__PACKAGE__->mk_accessors(@parameters);

sub _init {
    my ( $self, $params ) = @_;

    # propagate workflow condition parametrisation to our object
    foreach my $arg (@parameters) {
        if ( defined $params->{$arg} ) {
            $self->$arg( $params->{$arg} );
        }
    }
    if ( !( defined $self->array_name() ) ) {
        configuration_error "Missing parameter 'array_name' in "
            . "declaration of condition "
            . $self->name();
    }
}

sub _evaluate {

    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $array = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {   workflow    => $wf,
            context_key => $self->array_name(),
        }
    );

    if ( $self->condition() eq 'is_empty' ) {

        CTX('log')->application()->debug("Testing if WFArray ".$self->array_name()." is empty");

        if ( $array->count() == 0 ) {
            return 1;
        }
        condition_error ($self->error() || 'I18N_OPENXPKI_UI_CONDITION_ERROR_ARRAY_NOT_EMPTY');
    }
    elsif ( $self->condition() =~ /count_(is|lt|lte|gt|gte)/ ) {
        my $op = $1;
        my $cnt = $array->count();
        my $val = $self->value() || 0;

        CTX('log')->application()->debug("Testing if WFArray ".$self->array_name()." $op " . $self->value());

        if ($op eq 'is') {
            return 1 if ($cnt == $val);
        } elsif ($op eq 'is') {
            return 1 if ($cnt != $val);
        } elsif ($op eq 'lt') {
            return 1 if ($cnt < $val);
        } elsif ($op eq 'lte') {
            return 1 if ($cnt <= $val);
        } elsif ($op eq 'gt') {
            return 1 if ($cnt > $val);
        } elsif ($op eq 'gte') {
            return 1 if ($cnt >= $val);
        }
        condition_error ($self->error() || 'I18N_OPENXPKI_UI_CONDITION_ERROR_ARRAY_INVALID_ITEM_COUNT');

    }
    else {
        configuration_error "Invalid condition "
            . $self->condition() . " in "
            . "declaration of condition "
            . $self->name();
    }
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WFArray

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Condition::WFArray
    param
        array_name: cert_queue
        condition: count_lt
        value: 5

=head1 DESCRIPTION

Allows for checks of the contents of an array stored as a workflow
context parameter.

=head1 PARAMETERS

=head2 array_name

The name of the workflow context parameter containing the array to be used

=head2 condition

The following conditions are supported:

=over 8

=item is_empty

Condition is true if the array is either non-existent or is empty (I<value> is not used).

=item count_is

Condition is true if the number of elements matches the value set in C<value>.

=item count_ne

Condition is true if the number of elements does not match the value set in C<value>.

=item count_lt

Condition is true if the number of elements is less than the value set in C<value>.

=item count_lte

Condition is true if the number of elements is less than or equal the value set in C<value>.

=item count_gt

Condition is true if the number of elements is greater than the value set in C<value>.

=item count_gte

Condition is true if the number of elements is greater than or equal the value set in C<value>.

=back

head2 value

Value of the operand for the given condition operator.




