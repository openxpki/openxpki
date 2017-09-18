package OpenXPKI::Server::API2::CommandMetaClass;
=head1 Name

OpenXPKI::Server::API2::CommandMetaClass - Moose metaclass for command classes
used to store some meta information (like the anonymous command parameter
classes)

=cut
use strict;
use warnings;

use Class::MOP;

use parent 'Moose::Meta::Class';

# This is like: has api_param_classes => (...);
__PACKAGE__->meta->add_attribute('api_param_classes' => ( # copied from Moose::Meta::Class
    accessor => 'api_param_classes',
    default => sub { {} },
    Class::MOP::_definition_context(),
));

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
