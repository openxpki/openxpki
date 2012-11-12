# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::SCEPv2::ValidSCEPTID;
use base qw( Workflow::Condition );

my $flagname = 'f_valid_scep_tid';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
