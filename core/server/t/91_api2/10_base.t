#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level => $ENV{TEST_VERBOSE} ? $DEBUG : $OFF,
    layout  => '# %-5p %m%n',
});

# Project modules
use lib "$Bin/lib";


plan tests => 11;


use_ok "OpenXPKI::Server::API2";

my $api;
lives_ok {
    $api = OpenXPKI::Server::API2->new(
        namespace => "OpenXPKI::TestCommands",
        log => Log::Log4perl->get_logger(),
        enable_acls => 0,
    );
} "instantiate";

lives_and {
    my @commands = $api->register_plugin("OpenXPKI::Testalienplugin");
    cmp_deeply \@commands, [ 'alienplugin' ];
} "manually register a plugin class";

lives_and {
    cmp_deeply [ keys %{ $api->commands } ], bag('givetheparams', 'scream', 'alienplugin');
} "query available commands";

TODO: {
    local $TODO = "Implement strict constructor check for parameter objects";
    dies_ok {
        $api->dispatch(command => "givetheparams", params => { name => "Max", test => 1 });
    } "complain about unknown parameter";
};

throws_ok {
    $api->dispatch(command => "iamnothere");
} "OpenXPKI::Exception", "complain about unknown API command";

throws_ok {
    $api->dispatch(command => "givetheparams", params => { name => "Max", size => 1, level => 'WRONGVAL' });
} qr/ level .* 'Int' .* WRONGVAL /msxi, "complain about wrong parameter type";

use DateTime;
throws_ok {
    $api->dispatch(command => "givetheparams", params => { name => DateTime->now });
} qr/ name .* matching /msxi, "complain about wrong parameter type (with 'matching' defined)";

throws_ok {
    $api->dispatch(command => "givetheparams", params => { name => "Donald" });
} qr/ name .* matching /msxi, "complain about parameter validation failure (regex)";

throws_ok {
    $api->dispatch(command => "givetheparams", params => { name => "Max", size => -1 });
} qr/ size .* matching /msxi, "complain about parameter validation failure (sub)";

lives_and {
    my $result = $api->dispatch(command => "givetheparams", params => { name => "Max", size => 5, level => 4 });
    cmp_deeply $result, { name => "Max", size => 5, level => 4 };
} "correctly execute command";

1;
