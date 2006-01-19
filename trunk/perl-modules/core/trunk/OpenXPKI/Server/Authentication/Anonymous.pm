## OpenXPKI::Server::Authentication::Anonymous.pm 
##
## Written by Michael Bell 2006
## Copyright (C) 2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Server::Authentication::Anonymous;

use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG     => 0,
               };

    bless $self, $class;

    my $keys = shift;
    $self->{DEBUG} = 1 if ($keys->{DEBUG});
    $self->debug ("start");

    $self->{ROLE} = CTX('xml_config')->get_xpath (
                        XPATH   => [@{$keys->{XPATH}},   "role"],
                        COUNTER => [@{$keys->{COUNTER}}, 0]);

    return $self;
}

sub login
{
    my $self = shift;
    $self->debug ("start");
    return 1;
}

sub get_user
{
    my $self = shift;
    $self->debug ("start");
    return "";
}

sub get_role
{
    my $self = shift;
    $self->debug ("start");
    return $self->{ROLE};
}

1;
__END__

=head1 Description

This is the class which supports OpenXPKI with an anonymous
authentication method. The parameters are passed as a hash reference.

=head1 Functions

=head2 new

is the constructor. The supported parameters are DEBUG, XPATH and COUNTER.
This is the minimum parameter set for any authentication class.

=head2 login

returns always a true value.

=head2 get_user

returns always an empty string.

=head2 get_role

returns the role which is specified in the configuration. The configuration must
support a parameter role.
