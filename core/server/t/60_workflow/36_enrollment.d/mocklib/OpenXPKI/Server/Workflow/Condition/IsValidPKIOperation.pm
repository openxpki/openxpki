# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::IsValidPKIOperation;
use base qw( Workflow::Condition );

my $flagname = 'pki_operation';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
