package OpenXPKI::TestCommands;
use OpenXPKI -class;

with 'OpenXPKI::Base::API::APIRole';

# required by OpenXPKI::Base::API::APIRole
sub namespace { __PACKAGE__ }

__PACKAGE__->meta->make_immutable;
