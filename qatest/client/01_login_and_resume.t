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
use lib "$Bin/../lib", "$Bin/../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 7;


#
# Setup test env
#
my $oxitest = OpenXPKI::Test->new(
    with => [ "SampleConfig", "Server" ],
    also_init => "crypto_layer",
);

#
# Tests
#
my $tester = $oxitest->new_client_tester;
$tester->login("caop");

my $result = $tester->send_ok('COMMAND', { COMMAND => "get_session_info" });
is $result->{name}, "caop", "session info contains user name";

my $session_id = $tester->client->get_session_id;

$tester->client->close_connection;


my $tester2 = $oxitest->new_client_tester;
$tester2->init_session({ SESSION_ID => $session_id });


$oxitest->stop_server;

1;
