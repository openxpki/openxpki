## OpenXPKI::Workflow::Config
##
package OpenXPKI::Workflow::Context;

use strict;
use warnings;
use English;
use Encode;
use Workflow 1.39;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );

use base qw( Workflow::Context );

sub init {

    my $self = shift;

    $self->{_updated} = {};
    $self->{_init} = 0;

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
        # scalar items are not set with the correct utf8 encoding so we fix them here
        # non scalars are magically fixed by the JSON encoding later
        # do not run utf8 encoding on binary data
        if ( !ref $value && !$self->{_init} && $value !~ m{\x00}xms ) {
            eval {
                $value = Encode::decode("UTF-8", $value, Encode::LEAVE_SRC | Encode::FB_CROAK);
            };
            if ($EVAL_ERROR) {
                ##! 64: 'Decode error on ' . $value
                CTX('log')->workflow()->debug("Unable to decode value for $name");
            }
        }
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