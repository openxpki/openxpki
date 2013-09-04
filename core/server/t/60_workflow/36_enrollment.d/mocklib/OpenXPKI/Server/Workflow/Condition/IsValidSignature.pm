# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::IsValidSignature;
use base qw( Workflow::Condition );

my $flagname = 'signer_cert';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
