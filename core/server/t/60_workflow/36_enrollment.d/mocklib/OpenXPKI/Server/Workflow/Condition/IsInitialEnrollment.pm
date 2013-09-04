# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::IsInitialEnrollment;
use base qw( Workflow::Condition );

my $flagname = 'initial_enrollment';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
