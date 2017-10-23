#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level => $ENV{TEST_VERBOSE} ? $DEBUG : $OFF,
    layout  => '# %-5p %m%n',
});

# Project modules
use lib "$Bin/lib";


plan tests => 10;


use_ok "OpenXPKI::Server::API2";

my $api;
lives_ok {
    $api = OpenXPKI::Server::API2->new(
        namespace => "OpenXPKI::TestCommands",
        log => Log::Log4perl->get_logger(),
        acl_rule_accessor => sub { { allow_all_commands => 1 } },
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
        $api->dispatch("master", "givetheparams", name => "Max", test => 1);
    } "complain about unknown parameter";
};

throws_ok {
    $api->dispatch("master", "iamnothere");
} "OpenXPKI::Exception", "complain about unknown API command";

throws_ok {
    $api->dispatch("master", "givetheparams", name => "Max", size => "blah");
} "Moose::Exception::ValidationFailedForTypeConstraint", "complain about wrong parameter type";

throws_ok {
    $api->dispatch("master", "givetheparams", name => "Donald");
} "Moose::Exception::ValidationFailedForTypeConstraint", "complain about parameter validation failure (regex)";

throws_ok {
    $api->dispatch("master", "givetheparams", name => "Max", size => -1);
} "Moose::Exception::ValidationFailedForTypeConstraint", "complain about parameter validation failure (sub)";

lives_and {
    my $result = $api->dispatch("master", "givetheparams", name => "Max", size => 5 );
    cmp_deeply $result, { name => "Max", size => 5 };
} "correctly execute command";

1;
