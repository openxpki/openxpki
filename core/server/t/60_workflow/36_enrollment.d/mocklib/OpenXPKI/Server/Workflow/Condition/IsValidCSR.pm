# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::IsValidCSR;
use base qw( Workflow::Condition );

my $flagname = 'csr';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
