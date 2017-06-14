use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

#
# setup
#
my $log = Log::Log4perl->get_logger;

#
# tests
#
use_ok("OpenXPKI::Server::Database");
my %params = (
    type =>       "SQLite",
    name =>       ":memory:",
    namespace =>  '',
);
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

my $dbh;
lives_ok { $dbh = $dbi->dbh } "fetch database handle";

ok $dbi->_dbix_handler_initialized, "connect to DB (init DBIx::Handler)";

done_testing;
