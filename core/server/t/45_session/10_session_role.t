#
# Test class implementing OpenXPKI::Server::Session::DriverRole
#
package OpenXPKI::Server::Session::Driver::TestDriver;
use Moose;
use utf8;
with "OpenXPKI::Server::Session::DriverRole";

has save_called => (is => 'rw', isa => 'Bool', default => 0 );
has load_called => (is => 'rw', isa => 'Bool', default => 0 );

sub save { shift->save_called(1) }
sub load { shift->load_called(1); return {} }
sub delete {  }
sub delete_all_before {  }

__PACKAGE__->meta->make_immutable;

#
# Tests
#
package main;
use strict;
use warnings;

# Core modules
use English;

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($OFF);


plan tests => 10;


use_ok "OpenXPKI::Server::Session";

## create new session
my $session;
lives_ok {
    $session = OpenXPKI::Server::Session->new(
        type => "TestDriver",
        log => Log::Log4perl->get_logger(),
    )->create;
} "create session 1";

# Test single attribute
lives_and {
    $session->data->user("oxi");
    is $session->data->user, "oxi";
} "set and get session attribute";

# Check automatically created ID
lives_and {
    like $session->id, qr/\w+/;
} "session ID is automatically created";

# Set all attributes
for my $name (grep { $_ !~ /^ ( modified | _secrets | is_valid ) $/msx } @{ $session->data->get_attribute_names }) {
    $session->data->$name(int(rand(2**32-1)));
}

# Complain about wrong attribute
throws_ok {
    $session->data_as_hashref("id", "ink");
} qr/ unknown .* ink /msxi, "get_attributes() - complain about wrong attribute";

# Freeze (serialize) and thaw (deserialize)
my ($frozen1, $frozen2);
lives_ok {
    $frozen1 = $session->data->freeze(except => [ "user" ]);
    $frozen2 = $session->data->freeze(only => [ "user" ]);
} "freeze session 1 data";

lives_and {
    my $session_data = $session->data_as_hashref;
    delete $session_data->{user}; # we specified freeze(except => "user") above

    my $session2 = OpenXPKI::Server::Session->new(type => "TestDriver")->create;
    $session2->data->thaw($frozen1);

    cmp_deeply $session2->data_as_hashref, $session_data;
} "thaw data (except 'user') into session 2";

lives_and {
    my $session3 = OpenXPKI::Server::Session->new(type => "TestDriver")->create;
    $session3->data->thaw($frozen2);

    cmp_deeply $session3->data_as_hashref, { user => $session->data->user, created => ignore(), is_valid => ignore() };
} "thaw data (only 'user') into session 3";

# Persist (virtually in our test case)
lives_and {
    $session->persist;
    is $session->driver->save_called, 1;
} "persist session / call _save()";

throws_ok {
    # our test driver just returns an empty hash in _load()
    OpenXPKI::Server::Session
        ->new(
            type => "TestDriver",
            log =>  Log::Log4perl->get_logger(),
        )
        ->resume(25);
} qr/invalid/i, "complain about wrong results from driver";

1;
