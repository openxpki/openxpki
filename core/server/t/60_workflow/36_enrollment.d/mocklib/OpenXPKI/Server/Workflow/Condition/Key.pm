# Mock original module
#
# Note: for our tests, it is not relevant whether we test the logic
# branch where the ca key is not usable.

package OpenXPKI::Server::Workflow::Condition::Key;
use base qw( Workflow::Condition );


#my $flagname = 'csr';

sub evaluate {
    my ( $self, $wf ) = @_;

#    return $wf->context->param($flagname) || condition_error $flagname . ' is false';
    return 1;
}

1;
