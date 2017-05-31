package main;
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Server::Log;
use OpenXPKI::Server::Log::NOOP;
use OpenXPKI::Test;


#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Session.*'} = 100;


plan tests => 8;

#
# Setup test env
#
my $oxitest = OpenXPKI::Test->new;
$oxitest->setup_env->init_server;

my $log = $ENV{VERBOSE}
    ? OpenXPKI::Server::Log->new(CONFIG => "$Bin/log4perl.conf")
    : OpenXPKI::Server::Log::NOOP->new;

my $session_dir = tempdir( CLEANUP => 1 );

#
# Tests
#
use_ok "OpenXPKI::Server::SessionHandler";

my %base_args = (
    type => "File",
    log  => $log,
    driver_config => { directory => $session_dir },
);

## create new session
my $session;
lives_ok {
    $session = OpenXPKI::Server::SessionHandler->new(%base_args);
} "create file backed session";

# set all attributes
for my $name (grep { $_ ne "modified" } @{ $session->data->get_attribute_names }) {
    $session->data->$name(int(rand(2**32-1)));
}

# persist
lives_ok {
    $session->persist;
} "persist session";

my $session2;
lives_and {
    $session2 = OpenXPKI::Server::SessionHandler->new(%base_args);
    ok $session2->resume($session->id);
} "resume session";

# verify data is equal
lives_and {
    my $d1 = $session->data_as_hashref;  delete $d1->{modified};
    my $d2 = $session2->data_as_hashref; delete $d2->{modified};
    cmp_deeply $d2, $d1;
} "data is the same after freeze-thaw-cycle";

# make sure session expires
sleep 2;

lives_and {
    my $temp = OpenXPKI::Server::SessionHandler->new(%base_args, lifetime => 1);
    ok not $temp->resume($session->id);
} "fail resuming an expired session";

my $session3;
lives_ok {
    $session3 = OpenXPKI::Server::SessionHandler->new(%base_args, lifetime => 1);
    $session3->purge_expired;
} "purge expired sessions from backend";

lives_and {
    ok not $session3->driver->load($session->id);
} "fail loading a purged session";

1;
