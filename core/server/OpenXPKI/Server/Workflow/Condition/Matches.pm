package OpenXPKI::Server::Workflow::Condition::Matches;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );

sub _evaluate {

    ##! 64: 'start'
    my ( $self, $wf ) = @_;

    my $key = $self->param('key') || configuration_error('no key given');
    my $regex = $self->param('regex') || configuration_error('no regex given');

    my $modifier = $self->param('modifier') || '';
    ##! 32: "$key / $regex / $modifier"

    my $value = $wf->context->param->{$key} || '';

    $modifier =~ s/\s//g;
    if ($modifier) {
        configuration_error('unexpected modifier')
            unless ($modifier =~ /\A[alupimsx]+\z/ );

        $regex = qr/(?$modifier)$regex/;
    } else {
        $regex = qr/(?$modifier)$regex/;
    }

    $self->log->info("Evaluate $key to match reference value");

    ##! 32: $value
    condition_error('value does not match regex') unless($value =~ $regex);

    return 1;

}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::Matches

=head1 DESCRIPTION

This condition checks if the value of the context key given by I<key>
matches the regular expression given via I<regex>.

Note: an undefined context value is mapped to the empty string.

=head1 Configuration

  has_cert_subject_set:
      class: OpenXPKI::Server::Workflow::Condition::Matches
      param:
          key: cert_subject
          regex: tls_server
          modifier: xi

=head2 Arguments

=over

=item key

The context key to evaluate

=item value

A static string to match against

=item regex

A regular expression to match against

=item modifier

Modifier to add to the regular expression

=back