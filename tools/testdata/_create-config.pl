#!/usr/bin/env perl
#
# Setup an OpenXPKI test configuration in the temporary directory given as
# first argument.
#
# MySQL config will be read from env vars $OXI_TEST_DB_MYSQL_xxx.
#
use strict;
use warnings;

use File::Spec::Functions qw( catfile catdir splitpath rel2abs );

use lib catdir((splitpath(rel2abs(__FILE__)))[0,1])."/../../core/server/t/lib";
use OpenXPKI::Test::Config;

die "Base path for OpenXPKI test environment must be specified as first parameter"
    unless $ARGV[0] and -d $ARGV[0];

print "Setting up OpenXPKI test environment in $ARGV[0]\n";

OpenXPKI::Test::Config->new(
    basedir => $ARGV[0],
    db_type => "MySQL",
    db_name => $ENV{OXI_TEST_DB_MYSQL_NAME},
    db_host => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
    db_port => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
    db_user => $ENV{OXI_TEST_DB_MYSQL_USER},
    db_passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
)->create;
