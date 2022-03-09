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
$oxitest->client->login("democa" => "caop");

my $result = $oxitest->client->send_command_ok("get_session_info");
is $result->{name}, "caop", "session info contains user name";

my $session_id = $oxitest->client->oxi_client->get_session_id;

$oxitest->client->oxi_client->close_connection;


my $client2 = $oxitest->new_client_tester;
$client2->init_session({ SESSION_ID => $session_id });


$oxitest->stop_server;

done_testing;
