# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::SCEPv2::SignerValidityOK;
use base qw( Workflow::Condition );

my $flagname = 'f_signer_validity_ok';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
