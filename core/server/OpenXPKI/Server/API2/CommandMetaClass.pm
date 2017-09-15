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

# This is like: has api_param_classes => (...);  --> taken from Moose::Meta::Class
__PACKAGE__->meta->add_attribute('api_param_classes' => (
    accessor => 'api_param_classes',
    default => sub { {} },
    Class::MOP::_definition_context(),
));

1;
