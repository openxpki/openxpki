#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Exception;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 2;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( CryptoLayer )],
);

#
# Tests
#

# Fetch certificate - HASH Format
my ($r1, $r2);
lives_and {
    $r1 = $oxitest->api2_command("get_random" => { length => 9 });
    is length($r1), 12; # 9 bytes base64 encoded result in a 12 byte string
} "get_random - create 9 byte random";

lives_and {
    $r2 = $oxitest->api2_command("get_random" => { length => 9 });
    isnt $r1, $r2;
} "two randoms differ";
