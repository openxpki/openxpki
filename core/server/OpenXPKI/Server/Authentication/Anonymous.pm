## OpenXPKI::Server::Authentication::Anonymous.pm
##
## Written 2006 by Michael Bell
## Updated to use new Service::Default semantics 2007 by Alexander Klink
## (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Server::Authentication::Anonymous;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $path = shift;
    ##! 1: "start"

    $self->{ROLE} = CTX('config')->get("$path.role") || 'Anonymous';
    $self->{USER} = CTX('config')->get("$path.user") || 'anonymous';

    ##! 2: "role: ".$self->{ROLE}

    return $self;
}

sub login_step {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};

    return (
        $self->{USER},
        $self->{ROLE},
        {
            SERVICE_MSG => 'SERVICE_READY',
        },
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::Anonymous

=head1 Description

This is the class which supports OpenXPKI with an anonymous authentication
method. The parameters are passed as a hash reference. You can give a role
and a user name in the config, default is role = Anonymous, User = anonymous

=head1 Functions

=head2 new

is the constructor. It requires the config prefix as single argument.

=head2 login_step

returns the triple (I<user>, I<role>, and the service ready message)
