package OpenXPKI::Server::Workflow::Condition::IsTrue;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );


sub _evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;

    my $key = $self->param('key');

    configuration_error('no key given') unless($key);

    $self->log->info("Evaluate $key to be trueish");

    my $value = $self->_from_context($key);
    ##! 32: $value

    condition_error('trueish value is undefined') unless(defined $value);

    # value is scalar
    if (!ref $value) {
        condition_error('trueish value is empty')
            unless($value ne "");

        condition_error('trueish value is zero')
            unless($value !~ m{\A0+(.0+)?\z});

    # value is a hash
    } elsif (ref $value eq 'HASH') {

        condition_error('trueish value is empty hash')
            unless(scalar (keys $value->%*));

    # value is a list
    } elsif (ref $value eq 'ARRAY') {

        condition_error('trueish value is empty list')
            unless(scalar (keys $value->@*));

    } else {

        condition_error('trueish value is of unsupported type')

    }

    return 1;

}
1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsTrue

=head1 DESCRIPTION

Check the context key given by I<key> to contain a "true-sh" value
in perl terms (defined, not empty, not zero).

If the value is a list or hash, checks for a non-zero length.

=head1 Configuration

  has_cert_subject_set:
      class: OpenXPKI::Server::Workflow::Condition::IsTrue
      param:
          key: cert_subject

=head2 Arguments

=over

=item key

The context key to evaluate

=back