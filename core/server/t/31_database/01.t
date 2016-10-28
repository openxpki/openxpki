use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use File::Spec;
use File::Temp qw( tempdir );

#plan tests => 9;


my $basedir = File::Spec->catdir((File::Spec->splitpath(File::Spec->rel2abs(__FILE__)))[0,1]);

## prepare log system
use OpenXPKI::Server::Log;
my $log = OpenXPKI::Server::Log->new(CONFIG => File::Spec->catfile($basedir, "log4perl.conf"));
ok($log, "Log object initialized");

my %params = (
    type =>       "SQLite",
    name =>       ":memory:",
    namespace =>  '',
);

use_ok("OpenXPKI::Server::Database");

my $dbi;

# create faulty instance
lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log,
    db_params => {
        %params,
        type => undef,
    }
) };

throws_ok { $dbi->driver } qr/\btype\b.*missing/, "Complain about missing 'type' parameter";

# create correct instance
lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log,
    db_params => \%params,
) } "create instance";

lives_ok { $dbi->driver } "fetch driver object";

my $builder;
lives_ok { $builder = $dbi->query_builder } "fetch query builder object";

ok !$dbi->_dbix_handler_initialized, "dont connect to DB if not necessary";

my $sql;

# LIMIT ... OFFSET
lives_ok {
    $sql = $builder->select(
        from => 'flora',
        columns => [ qw ( name color ) ],
        where => { fruits => 'forbidden' },
        limit => 5,
        offset => 10,
    )->string
} "create SELECT query with LIMIT and OFFSET";

like $sql,
    qr/ ^
        SELECT \W+ name, \W+ color \W+
        FROM \W+ flora \W
        WHERE .*
        LIMIT .* OFFSET
    /xmsi, "correct SQL string";

# JOIN
lives_ok {
    $sql = $builder->select(
        from_join => 'fruit id=id flora',
        columns => [ qw ( name color ) ],
        where => { fruits => 'forbidden' },
    )->string
} "create SELECT query with JOIN";


like $sql,
    qr/ ^
        SELECT \W+ name, \W+ color \W+
        FROM \W+ fruit \W
        .*? JOIN \W+ flora \W+
        ON \W+ fruit\.id \W+ = \W+ flora\.id \W+
        WHERE
    /xmsi, "correct SQL string";


my $dbh;
lives_ok { $dbh = $dbi->dbh } "fetch database handle";

ok $dbi->_dbix_handler_initialized, "connect to DB (init DBIx::Handler)";

done_testing;
