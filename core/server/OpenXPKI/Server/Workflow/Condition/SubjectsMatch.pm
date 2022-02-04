
package OpenXPKI::Server::Workflow::Condition::SubjectsMatch;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;


sub _evaluate {
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)

    my $subject1 = $self->param('subject1') || '';
    my $subject2 = $self->param('subject2') || '';

    if (!$subject1 || !$subject2) {
        condition_error('subject match subject is empty');
    }

    if ($self->param('ignore_case')) {
        $subject1 = lc($subject1);
        $subject2 = lc($subject2);
    }

    if ($self->param('cn_only')) {
        my %dn1 = OpenXPKI::DN->new( $subject1 )->get_hashed_content();
        my %dn2 = OpenXPKI::DN->new( $subject2 )->get_hashed_content();

        $subject1 = $dn1{CN}[0];
        $subject2 = $dn2{CN}[0];
    }

    if (!$subject1 || $subject1 ne $subject2) {
        condition_error('subject match subjects dont match');
    }
    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SubjectsMatch


=head1 DESCRIPTION

This condition compares two subjects for identical parts.
The default is to compare the full subject strings as passed to the class,
passing extra parameters change this behaviour.

=head2 Paramaters

=over

=item subject1

=item subject2

=item cn_only

Boolean, if set only the CN is compared

=item ignore_case

Boolean, if set all checks are done case insensitive

=back
