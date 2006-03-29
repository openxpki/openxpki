## OpenXPKI::Service::Test.pm 
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Service::Test;

## used modules

use OpenXPKI qw(debug);
use OpenXPKI::Exception;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {DEBUG => 0};

    bless $self, $class;

    my $keys = shift;
    $self->{DEBUG}                = 1                             if ($keys->{DEBUG});
    $self->{AUTHENTICATION_STACK} = $keys->{AUTHENTICATION_STACK} if ($keys->{AUTHENTICATION_STACK});
    $self->{LOGIN}                = $keys->{LOGIN}                if ($keys->{LOGIN});
    $self->{PASSWD}               = $keys->{PASSWD}               if ($keys->{PASSWD});

    return $self;
}

sub init
{
    my $self = shift;
    return 1;
}

sub run
{
    my $self = shift;
    return 1;
}

sub get_authentication_stack
{
    my $self = shift;
    $self->debug ("reached");
    return $self->{AUTHENTICATION_STACK};
}

sub get_passwd_login
{
    my $self = shift;
    my $name = shift;
    $self->debug ("handler $name");
    return ($self->{LOGIN}, $self->{PASSWD});
}

1;
__END__

=head1 Description

This module is only used to test the server. It is a simple dummy
class which does nothing.

=head1 Functions

The functions does nothing else than to support the test stuff
with a working user interface dummy.

=over

=item * new

=item * init

=item * run

=item * get_authentication_stack

=item * get_passwd_login

=back
