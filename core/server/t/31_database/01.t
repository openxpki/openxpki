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

my $conn;
lives_ok { $conn = $dbi->_connector } "Fetch connector object";

throws_ok { $conn->driver } qr/\btype\b.*missing/, "Complain about missing 'type' parameter";

# create correct instance
lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log,
    db_params => \%params,
) } "create instance";

my $query;
lives_ok { $query = $dbi->query } "fetch query object";

my $sql;
lives_ok {
    $sql = $query->select(
        from => 'flora',
        columns => [ qw ( name color ) ],
        where => { fruits => 'forbidden' },
        limit => 5,
        offset => 10,
    )->sql_str
} "create SELECT query with LIMIT and OFFSET";

like $sql, qr/SELECT\s*name,\s*color\s*FROM\s*flora\s*WHERE.*LIMIT.*OFFSET/i, "correct SQL string";

lives_ok { $conn = $dbi->_connector } "fetch connector object";
lives_ok { $conn->driver } "fetch driver object";

my $dbh;
lives_ok { $dbh = $dbi->dbh } "fetch database handle";

done_testing;
