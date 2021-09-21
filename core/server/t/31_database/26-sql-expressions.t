use strict;
use warnings;
use English;

#
# Test correct translation of DBMS specific SQL expressions
#

use Test::More;
use Test::Exception;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

#
# setup
#
my $log = Log::Log4perl->get_logger;

use_ok("OpenXPKI::Server::Database");

my $mariadb_expr = 'EXTRACT(YEAR FROM FROM_UNIXTIME(notbefore))';

my $expected = {
    MariaDB    => qr/^extract \( year \s+ from \s+ from_unixtime \( notbefore \) \)/msxi,
    MySQL      => qr/^extract \( year \s+ from \s+ from_unixtime \( notbefore \) \)/msxi,
    Oracle     => qr/^extract \( year \s+ from \s+ to_date \( '19700101' , 'YYYYMMDD' \) \+ \( 1\/86400 \) \* notbefore \)/msxi,
    PostgreSQL => qr/^extract \( year \s+ from \s+ to_timestamp \( notbefore \) \)/msxi,
    SQLite     => qr/^strftime \( '%Y' , datetime \( notbefore , 'unixepoch' \) \)/msxi,
};

for my $driver (sort keys %$expected) { # MySQL PostgreSQL SQLite Oracle DB2
    subtest "$driver: SELECT with FROM_UNIXTIME ()" => sub {
        my $dbi;
        lives_ok { $dbi = OpenXPKI::Server::Database->new(
            log => $log,
            db_params => { type => $driver, name => "dummy" },
        ) } "dbi instance";

        #
        # tests
        #
        my $builder;
        lives_ok { $builder = $dbi->query_builder } "fetch query builder object";

        my $sql;

        # LIMIT ... OFFSET
        lives_ok {
            $sql = $builder->select(
                from => 'certificate',
                columns => [ $mariadb_expr ],
            )->string
        } "SELECT query";

        # strip some whitespaces
        $sql =~ s/\(\s+/(/gmsi;
        $sql =~ s/\s+\)/)/gmsi;
        $sql =~ s/\s*([+*,])\s*/$1/gmsi;

        my ($got) = $sql =~ qr/ ^
            SELECT \s+ (.*?) \s*
            FROM \s+ certificate \s*
        /xmsi;

        like $got, $expected->{$driver}, "correct expression replacement";
    };
}

done_testing;
