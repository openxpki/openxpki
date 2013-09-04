# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::SCEPv2::SignerCertCryptOK;
use base qw( Workflow::Condition );

my $flagname = 'f_signer_cert_crypt_ok';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
