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
use lib "$Bin/../../core/server/t/lib";
use OpenXPKI::Test::ConfigWriter;

die "Base path for OpenXPKI test environment must be specified as first parameter"
    unless $ARGV[0] and -d $ARGV[0];

print "Setting up OpenXPKI test environment in $ARGV[0]\n";

OpenXPKI::Test::ConfigWriter->new(
    basedir => $ARGV[0],
    db_conf => {
        type => "MySQL",
        name => $ENV{OXI_TEST_DB_MYSQL_NAME},
        host => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
        port => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
        user => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
    }
)->create;
