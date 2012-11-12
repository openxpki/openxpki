# Mock original module
#

package OpenXPKI::Server::Workflow::Condition::IsValidPKCS7;
use base qw( Workflow::Condition );

my $flagname = 'pkcs7';

sub evaluate {
    my ( $self, $wf ) = @_;

    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
}

1;
