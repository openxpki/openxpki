# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::IsValidChallengePassphrase;
use base qw( Workflow::Condition );

my $flagname = 'challenge_pass';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
