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


use_ok "OpenXPKI::TestCommandsNamespace";

my $auto;
lives_ok {
    $auto = OpenXPKI::TestCommandsNamespace->new(
        log => Log::Log4perl->get_logger(),
        enable_acls => 0,
    )->autoloader;
} "instantiate";

throws_ok {
    $auto->TheUnknown;
} qr/unknown[\w\s]+command/i, "complain about unknown command in root namespace";

throws_ok {
    $auto->config->create;
} qr/unknown[\w\s]+command/i, "complain about unknown command";

lives_and {
    my $result = $auto->info(size => 5, level => 3);
    cmp_deeply $result, { size => 5, level => 3 };
} "correctly execute command";

lives_and {
    my $result = $auto->config->info;
    is $result, 'CONFIG_INFO';
} "execute config.info";

done_testing;
