package OpenXPKI::TestCommandsTypes;
use OpenXPKI -class;

with 'OpenXPKI::Base::API::APIRole';

# required by OpenXPKI::Base::API::APIRole
sub namespace { __PACKAGE__ }
sub handle_dispatch_error ($self, $err) { die $err }

__PACKAGE__->meta->make_immutable;
