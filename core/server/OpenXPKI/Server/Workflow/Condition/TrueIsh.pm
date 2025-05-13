package OpenXPKI::Server::Workflow::Condition::TrueIsh;
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

    my $value = $wf->context->param->{$key};
    ##! 32: $value

    condition_error('trueish value is undefined') unless(defined $value);

    condition_error('trueish value is empty') unless($value != "");

    condition_error('trueish value is zero') unless($value != 0);


}
1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::TrueIsh

=head1 DESCRIPTION

This condition checks the context key given by I<key> to be "trueish"
in perl terms (defined, not empty, not zero).

=head1 Configuration

  has_cert_subject_set:
      class: OpenXPKI::Server::Workflow::Condition::TrueIsh
      param:
          key: cert_subject

=head2 Arguments

=over

=item key

The context key to evaluate

=back