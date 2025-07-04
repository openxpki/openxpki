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
    level => $ENV{TEST_VERBOSE} ? $TRACE : $OFF,
    layout  => '# %-5p %m%n',
});

# Project modules
use lib "$Bin/lib";


use_ok "OpenXPKI::TestCommands";

my $api;
lives_ok {
    $api = OpenXPKI::TestCommands->new(
        log => Log::Log4perl->get_logger(),
        enable_acls => 0,
        disable_protection => 1,
    );
} "instantiate";

lives_and {
    cmp_deeply $api->rel_namespaces, [ '' ];
} "query available namespaces (only root = \"\")";

lives_and {
    is $api->has_non_root_namespaces, 0;
} "has_non_root_namespaces == FALSE";

lives_and {
    cmp_deeply [ keys $api->namespace_commands->%* ], bag('givetheparams', 'scream', 'protected');
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
} "execute standard command";

lives_and {
    my $result = $api->dispatch(command => "protected", params => { echo => "Hello" });
    is $result, "Hello";
} "execute protected command like any other with API protection disabled";

lives_ok {
    $api = OpenXPKI::TestCommands->new(
        log => Log::Log4perl->get_logger(),
        enable_acls => 0,
    );
} "instantiate API in DOS Protected Mode :-)";

lives_and {
    my $result = $api->dispatch(command => "givetheparams", params => { name => "Max", size => 5, level => 4 });
    cmp_deeply $result, { name => "Max", size => 5, level => 4 };
} "execute standard command";

throws_ok {
    $api->dispatch(command => "protected", params => { echo => "Hello" });
} qr/ call .* protected /msxi, "complain about calling protected command without explicit flag";

lives_and {
    my $result = $api->dispatch(command => "protected", params => { echo => "Hello" }, protected_call => 1);
    is $result, "Hello";
} "execute protected command with explicit flag";

done_testing;
