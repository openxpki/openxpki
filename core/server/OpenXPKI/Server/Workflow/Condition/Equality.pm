package OpenXPKI::Server::Workflow::Condition::Equality;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );

sub _evaluate {

    ##! 64: 'start'
    my ( $self, $wf ) = @_;

    my $key = $self->param('key') || configuration_error('no key given');

    my $reference = $self->param('value') // configuration_error('no reference value given');


    ##! 32: "$key / $reference"

    $self->log->info("Evaluate $key to match reference value");

    my $value = $wf->context->param->{$key};
    ##! 32: $value

    condition_error('value is undefined') unless(defined $value);

    condition_error('value is empty') unless($value != "");

    condition_error('value does not match reference') unless($value eq $reference);


}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Equality

=head1 DESCRIPTION

This condition checks if the value of the context key given by I<key>
matches the reference value given as I<value>.

=head1 Configuration

  has_cert_subject_set:
      class: OpenXPKI::Server::Workflow::Condition::Matches
      param:
          key: cert_subject
          value: tls_server

=head2 Arguments

=over

=item key

The context key to evaluate

=item value

A static string to match against

=back