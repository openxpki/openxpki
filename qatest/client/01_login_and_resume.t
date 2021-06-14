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
my $client = $oxitest->new_client_tester;
$client->login("democa" => "caop");

my $result = $client->send_command_ok("get_session_info");
is $result->{name}, "caop", "session info contains user name";

my $session_id = $client->client->get_session_id;

$client->client->close_connection;


my $client2 = $oxitest->new_client_tester;
$client2->init_session({ SESSION_ID => $session_id });


$oxitest->stop_server;

1;
