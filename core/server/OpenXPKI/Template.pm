package OpenXPKI::Template;

use strict;
use warnings;
use utf8;

use base qw( Template );
use Data::Dumper;

#use OpenXPKI::Debug;
#use OpenXPKI::Exception;
#use OpenXPKI::Server::Context qw( CTX );

sub new {
    my $class = shift;
    my $args = shift;
    
    $args->{PLUGIN_BASE} = 'OpenXPKI::Template::Plugin';
    
    my $self = $class->SUPER::new($args);
    
    return $self;
}
    

1;