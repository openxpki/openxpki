package OpenXPKI::Server::Workflow::Condition::Compare;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );

sub _evaluate {

    ##! 64: 'start'
    my ( $self, $wf ) = @_;

    my $key = $self->param('key') || configuration_error('no key given');
    my $op = $self->param('operator') || configuration_error('no operator given');

    # value might be set via _map and be empty
    my $reference = $self->param('value') // condition_error('reference is empty');

    my $value = $wf->context->param->{$key};

    ##! 32: "$key / $reference /  $value"
    $self->log->info("Compare $key to reference value");

    condition_error('value is not numeric')
        unless($value =~ m{\A\d+(\.\d+)?\z});

    condition_error('reference value is not numeric')
        unless($reference =~ m{\A\d+(\.\d+)?\z});


    if ($op eq 'is') {
        condition_error('value is not equal to reference')
            unless ($value == $reference);
    }
    elsif ($op eq 'isnot') {
        condition_error('value is equal to reference but should not')
            unless ($value != $reference);
    }
    elsif ($op eq 'lt') {
        condition_error('value is not less than reference')
            unless ($value < $reference);
    }
    elsif ($op eq 'lte') {
        condition_error('value is not less or equal than reference')
            unless ($value <= $reference);
    }
    elsif ($op eq 'gt') {
        condition_error('value is not greater than reference')
            unless ($value > $reference);
    }
    elsif ($op eq 'gte') {
        condition_error('value is not greater or equal than reference')
            unless ($value >= $reference);
    } else {
        configuration_error('unexpected operator');
    }

    return 1;

}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Compare

=head1 DESCRIPTION

Numerically compare the value of the context key given by I<key>
against the value given to I<value>.

The condition is false if either argument is not numeric
(only decimal numbers are accepted)

=head1 Configuration

  has_approval_count:
      class: OpenXPKI::Server::Workflow::Condition::Compare
      param:
          key: approval_points
          operator: gte
          value: 2


=head2 Arguments

=over

=item key

The context key to evaluate

=item value

The value to compare against

=item operator

One of I<is>, I<isnot>, I<lt>, I<lte>, I<gt>, I<gte>

=back