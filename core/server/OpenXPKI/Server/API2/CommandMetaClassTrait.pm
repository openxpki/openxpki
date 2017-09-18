package OpenXPKI::Server::API2::CommandMetaClassTrait;
=head1 Name

OpenXPKI::Server::API2::CommandMetaClassTrait - Moose metaclass role (aka.
"trait") for command classes.

=head2 Description

This role is not intended to be used directly. It will be applied when you say
C<use OpenXPKI::Server::API2::Command>.

This role adds meta functionality to the classes that implement API commands.

=cut
use strict;
use warnings;

use Moose::Role;

has api_param_classes => (
    is => 'rw',
    isa => 'HashRef[Str]',
    default => sub { {} },
);

sub new_param_object {
    my ($self, $api_method, %params) = @_;
    my $param_metaclass = $self->api_param_classes->{$api_method};
    die "API method $api_method is not managed by __PACKAGE__\n" unless $param_metaclass;
    use Test::More;
    diag "==> new_param_object($api_method, ".join(", ", map { "$_ => $params{$_}" } keys %params).")";
    my $param_object = $param_metaclass->new_object(%params);
    diag "==> object created";
    return $param_object;
}

1;
