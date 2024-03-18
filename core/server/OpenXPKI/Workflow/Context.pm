package OpenXPKI::Workflow::Context;

use strict;
use warnings;
use English;
use Workflow 1.39;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );

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

        ##! 16: 'Mark updated values from hash: ' . join (",", keys %{$name})
        ##! 64: 'value hash ' . Dumper $name
        map {
            $self->param( $_ => $name->{$_} );
        } keys %{$name};
        return $self->SUPER::param();

    } elsif (defined $arg[0]) {

        if ($name eq 'workflow_id' &&  $self->{PARAMS}{'workflow_id'}) {
            OpenXPKI::Exception->throw( message => "You are not allowed to set workflow_id in context" );
        }

        $self->{_updated}->{$name} = 1;
        ##! 16: 'Mark updated value from scalar: ' . $name
        my $value = $arg[0];

        ##! 64: 'value is ' . Dumper $value
        return $self->SUPER::param( $name => $value );

    } elsif ( exists $arg[0] ) {

        ##! 16: 'Mark updated value (undef) from scalar: ' . $name

        $self->{_updated}->{$name} = 1;

        # the superclass does not handle key => undef but does handle
        # { key => undef } so we translate this here to have the short
        # syntax available in our application
        return $self->SUPER::param({ $name => undef });

    } else {

        ##! 16: 'Call without value'
        return scalar $self->SUPER::param( @_ );
    }

}

1;

__END__