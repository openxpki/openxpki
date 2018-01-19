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


plan tests => 3;


use_ok "OpenXPKI::Server::API2";

my $auto;
lives_ok {
    $auto = OpenXPKI::Server::API2->new(
        namespace => "OpenXPKI::TestCommands",
        log => Log::Log4perl->get_logger(),
        enable_acls => 0,
    )->autoloader;
} "instantiate";

lives_and {
    my $result = $auto->givetheparams(name => "Max", size => 5);
    cmp_deeply $result, { name => "Max", size => 5, level => 0 };
} "correctly execute command";

1;
