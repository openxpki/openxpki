# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::SCEPv2::ValidCSR;
use base qw( Workflow::Condition );

my $flagname = 'f_valid_csr';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
