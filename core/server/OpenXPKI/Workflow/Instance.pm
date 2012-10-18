

package OpenXPKI::Workflow::Instance;
use base qw( Workflow );

use strict;
use warnings;
use English;
use Moose;
use Data::Dumper;

# TODO - This is a stub for testing
# If we can submit the Upstream Patches to Workflow, we should refactor 
# The Oxi::Server::Workflow class to use proper inheritance 

sub init {
    
    my $self = shift;    
    $self->SUPER::init( @_ ); 
    
}

1;