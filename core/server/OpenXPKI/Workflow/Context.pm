## OpenXPKI::Workflow::Config
##
package OpenXPKI::Workflow::Context;

use strict;
use warnings;
use OpenXPKI::Debug;
use Workflow 1.39;

use base qw( Workflow::Context );

sub init {

    my $self = shift;

    $self->{_updated} = {};

    ##! 1: 'Initialize empty context'
    return $self->SUPER::init( @_ );

}

sub reset_updated {
    my $self = shift;
    $self->{_updated} = {};
    return $self;
}

sub param {

    my $self = shift;
    my @arg = @_;

    my $name = shift @arg;
    if ( ref $name eq 'HASH' ) {
        ##! 1: 'Mark updated from hash ' . join (",", keys %{$name})
        map { $self->{_updated}->{$_} = 1; } keys %{$name};

    } elsif ( exists $arg[0] ) {
        ##! 1: 'Mark updated from scalar ' . $name
        $self->{_updated}->{$name} = 1;
    } else {
        ##! 1: 'Call without value'
    }

    return $self->SUPER::param( @_ );

}

1;

__END__
