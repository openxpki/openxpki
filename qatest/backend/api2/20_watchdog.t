#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

#
# Init tests
#
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Server ) ],
    start_watchdog => 1,
);
#
# We have to test API command "control_watchdog" via a client due to the
# way OpenXPKI::Control->get_pids() collects process informations.
# If we directly called the API command, get_pids() would not see the watchdog
# processes started by the server as they would be in another process group as
# the test process (that calls the API).
#
my $client = $oxitest->new_client_tester->login("caop");

#
# Tests
#
sub is_run_status {
    my ($expected, $msg) = @_;

    my $MAX_WAIT = 5;
    my $tick = 0;

    while (1) {
        my $result = $client->send_command_api2_ok("control_watchdog" => { action => "status" });
        my $is_running = (scalar @{ $result->{pid} } > 0);
        if ($expected ? ($is_running) : (not $is_running)) { pass $msg and last };
        last if ++$tick == $MAX_WAIT;
        sleep 1;
    }
    fail $msg if $tick == $MAX_WAIT;
}

is_run_status 1, "status of running watchdog";

lives_and {
    $client->send_command_api2_ok("control_watchdog" => { action => "stop" });
    is_run_status 0;
} "stop watchdog";

lives_and {
    $client->send_command_api2_ok("control_watchdog" => { action => "start" });
    is_run_status 1;
} "start watchdog again";

lives_and {
    my $result = $client->send_command_api2_ok("control_watchdog" => { action => "status" });
    cmp_deeply $result, { pid => [ re(qr/^\d+$/) ], children => 0 }
} "watchdog status info";

done_testing;
