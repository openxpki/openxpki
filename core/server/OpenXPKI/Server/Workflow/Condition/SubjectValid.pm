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

    my $subject  = $context->param('cert_subject') || '';


    if (!$subject) {
        condition_error('Subject is empty!');
    }

    my %dn = OpenXPKI::DN->new( $subject )->get_hashed_content();

    if (length($dn{CN}[0]) > 64) {
        condition_error('Common Name exceeds 64 character limit');
    }

    foreach my $rdn (keys %dn) {
        ##! 16: 'Testing rdn ' . $rdn
        ##! 32: 'Component ' . Dumper $dn{$rdn}
        foreach my $comp (@{$dn{$rdn}}) {
            condition_error('Subject has empty components') if ($comp eq '');
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

Check if the subject has no empty RDNs and if the Common Name does not
exceed the 64 charater limit. Expects the subject to be in I<cert_subject>.
