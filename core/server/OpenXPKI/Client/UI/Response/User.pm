package OpenXPKI::Client::UI::Response::User;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

# The attributes are roughly equal to (and are built from) the results of the
# "get_session_info" API command, modified in OpenXPKI::Client::UI::Bootstrap.
has 'name' => (is => 'rw', isa => 'Str');
has 'role' => (is => 'rw', isa => 'Str');
has 'realname' => (is => 'rw', isa => 'Str');
has 'role_label' => (is => 'rw', isa => 'Str');
has 'pki_realm' => (is => 'rw', isa => 'Str');
has 'pki_realm_label' => (is => 'rw', isa => 'Str');
has 'checksum' => (is => 'rw', isa => 'Str');
has 'sid' => (is => 'rw', isa => 'Str');
has 'last_login' => (is => 'rw', isa => 'Int');
has 'tenants' => (is => 'rw', isa => 'ArrayRef');


sub is_set { shift->has_any_value }

__PACKAGE__->meta->make_immutable;
