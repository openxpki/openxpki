package OpenXPKI::Server::Workflow::Condition::IsEqual;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );

sub _evaluate {

    ##! 64: 'start'
    my ( $self, $wf ) = @_;

    my $key = $self->param('key') || configuration_error('no key given');

    # value might be set via _map and be empty
    my $reference = $self->param('value') // '';
    my $value = $wf->context->param->{$key};

    ##! 32: "$key / $reference /  $value"
    $self->log->info("Match $key against reference value");

    condition_error('value is undefined') unless(defined $value);

    condition_error('value is empty') unless($value ne "");

    condition_error('value does not match reference') unless($value eq $reference);

    return 1;

}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsEqual

=head1 DESCRIPTION

This condition checks if the value of the context key given by I<key>
matches the reference value given as I<value>.

=head1 Configuration

  has_cert_subject_set:
      class: OpenXPKI::Server::Workflow::Condition::IsEqual
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