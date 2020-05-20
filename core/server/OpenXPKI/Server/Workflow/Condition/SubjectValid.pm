package OpenXPKI::Server::Workflow::Condition::SubjectValid;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;

use Data::Dumper;

sub _evaluate {
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)

    my $subject  = $self->param('cert_subject') // $context->param('cert_subject');

    if (!$subject) {
        condition_error('Subject is empty!');
    }

    my %dn = OpenXPKI::DN->new( $subject )->get_hashed_content();

    my $max_length = {
        CN => 64,
        OU => 64,
        O => 64,
        L => 128,
        ST => 128,
        C => 2,
        %{$self->param()}
    };

    ##! 64: $max_length
    foreach my $rdn (keys %dn) {
        # we use the upper bound ub-name as absolute max
        my $maxlen = $max_length->{$rdn} || 32768;
        ##! 16: 'Testing rdn ' . $rdn . ' with maxlen of ' . $maxlen
        ##! 32: 'Component ' . Dumper $dn{$rdn}
        foreach my $comp (@{$dn{$rdn}}) {
            condition_error('Subject has empty components') if ($comp eq '');
            condition_error('RDN $rdn exceeds $maxlen character limit') if (length($comp) > $maxlen);
        }
    }

    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SubjectValid


=head1 DESCRIPTION

Subject can be set via param I<cert_subject>, if unset its read from
the context value I<cert_subject>.

Check if the subject has no empty RDNs and if the RDN components do not
exceed the the length limits. Length check is done on CN/OU/O (64),
L/ST (128), C (2). You can add extra checks by adding a parameter with
the RDN name as key, e.g.

  class: OpenXPKI::Server::Workflow::Condition::SubjectValid
  param:
      DC=256

To check any rdn for "DC" to be no larger than 256 chars.
