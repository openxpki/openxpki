#!/usr/bin/env perl
#
# Setup an OpenXPKI test configuration in the temporary directory given as
# first argument.
#
# MySQL config will be read from env vars $OXI_TEST_DB_MYSQL_xxx.
#
use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../core/server/t/lib", "$Bin/../../qatest/lib";
use OpenXPKI::Test;

die "Base path for OpenXPKI test environment must be specified as first parameter"
    unless $ARGV[0] and -d $ARGV[0];

print "Setting up OpenXPKI test environment in $ARGV[0]\n";

my $config = OpenXPKI::Test->new(
    testenv_root => $ARGV[0],
    db_conf => {
        type => "MySQL",
        $ENV{OXI_TEST_DB_MYSQL_DBHOST} ? ( host => $ENV{OXI_TEST_DB_MYSQL_DBHOST} ) : (),
        $ENV{OXI_TEST_DB_MYSQL_DBPORT} ? ( port => $ENV{OXI_TEST_DB_MYSQL_DBPORT} ) : (),
        name => $ENV{OXI_TEST_DB_MYSQL_NAME},
        user => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
    },
    with => [qw( TestRealms CryptoLayer )],
    test_realms => [qw( alpha beta gamma democa )]
);
