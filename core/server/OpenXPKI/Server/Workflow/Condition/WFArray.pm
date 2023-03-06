package OpenXPKI::Server::Workflow::Condition::WFArray;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Debug;
use English;

sub _evaluate {

    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $array_name = $self->param('array_name');
    my $condition  = $self->param('condition');

    my $array = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        {   workflow    => $wf,
            context_key => $array_name,
        }
    );

    ##! 32: 'Array ' .$self->name(). ', Condition '. $condition
    if ( $condition eq 'is_empty' ) {

        CTX('log')->application()->debug("Testing if WFArray ".$array_name." is empty");

        if ( $array->count() != 0 ) {
            condition_error ($self->param('error') || 'array not empty');
        }

    }
    elsif ( $condition eq 'is_not_empty' ) {

        CTX('log')->application()->debug("Testing if WFArray ".$array_name." is not empty");

        if ( $array->count() < 1 ) {
            condition_error ($self->param('error') || 'array is empty');
        }

    }
    elsif ( $condition =~ /count_(is|isnot|lt|lte|gt|gte)\s*$/ ) {

        my $op = $1;
        my $cnt = $array->count();
        my $val = $self->param('value') || 0;

        ##! 32: 'Value: '.$val.', Count: ' . $cnt, ' Op ' . $op

        CTX('log')->application()->debug("Testing if WFArray ".$array_name." $op " . $val);

        if ($op eq 'is') {
            return 1 if ($cnt == $val);
        } elsif ($op eq 'isnot') {
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
        ##! 16: 'Condition failed'
        condition_error ($self->param('error') || 'array has invalid item count');

    }
    elsif ( $condition eq 'match' || $condition eq 'nomatch' ) {

        my $regex = $self->param('regex');
        my $modifier = $self->param('modifier') // 'xi';
        $modifier =~ s/\s//g;
        if ($modifier =~ /[^alupimsx]/ ) {
            configuration_error( "Invalid modifier  $modifier" );
        }
        $modifier = "(?$modifier)" if ($modifier);
        $regex = qr/$modifier$regex/;

        ##! 16: 'Regex ' . $regex
        CTX('log')->application()->debug("Testing if WFArray matches regex $regex ");

        my @errors;
        foreach my $val (@{$array->values()}) {
            ##! 16: 'Test ' . $val
            ##! 8: 'Failed on ' . $val
            if ($condition eq 'match') {
                push @errors, $val if ($val !~ $regex);
            } else {
                push @errors, $val if ($val =~ $regex);
            }
        }

        if (scalar @errors) {
            condition_error ($self->param('error') || 'array does not match regex');
        }

    }
    else {

        CTX('log')->application()->error('Invalid configuration for Condition::WFArray: ' . $condition . ' on ' . $array_name);

        configuration_error "Invalid condition "
            . $condition . " in "
            . "declaration of condition "
            . $array_name;
    }

    return 1;
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

=item C<is_empty>

Condition is true if the array is either non-existent or is empty (I<value> is not used).

=item C<is_not_empty>

Condition is true if the array is not empty (I<value> is not used).

=item C<count_is>

Condition is true if the number of elements matches the value set in C<value>.

=item C<count_ne>

Condition is true if the number of elements does not match the value set in C<value>.

=item C<count_lt>

Condition is true if the number of elements is less than the value set in C<value>.

=item C<count_lte>

Condition is true if the number of elements is less than or equal the value set in C<value>.

=item C<count_gt>

Condition is true if the number of elements is greater than the value set in C<value>.

=item C<count_gte>

Condition is true if the number of elements is greater than or equal the value set in C<value>.

=back

head2 value

Value of the operand for the given condition operator.




