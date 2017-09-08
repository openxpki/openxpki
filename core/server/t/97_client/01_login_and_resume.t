package main;
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Test::Server;
use OpenXPKI::Test::Client;


plan tests => 7;


#
# Setup test env
#
my $oxitest = OpenXPKI::Test->new->setup_env;

my $server = OpenXPKI::Test::Server->new(oxitest => $oxitest);
$server->init_tasks( ['crypto_layer'] );
$server->start;

my $tester = OpenXPKI::Test::Client->new(oxitest => $oxitest);
#
# Tests
#
$tester->connect;
$tester->init_session;
$tester->login("caop");

my $result = $tester->send_ok('COMMAND', { COMMAND => "get_session_info" });
is $result->{name}, "caop", "session info contains user name";

my $session_id = $tester->client->get_session_id;

$tester->client->close_connection;

my $tester2 = OpenXPKI::Test::Client->new(oxitest => $oxitest);
$tester2->connect;
$tester2->init_session({ SESSION_ID => $session_id });

$server->stop;

1;
