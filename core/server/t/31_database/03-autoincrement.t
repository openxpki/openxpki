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

use_ok("OpenXPKI::Server::Database");
my $dbi;
lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log, db_params => { type => "SQLite", name => ":memory:" },
) } "dbi instance";

#
# tests
#
lives_ok {
    $dbi->run("CREATE TABLE test (id INTEGER PRIMARY KEY AUTOINCREMENT, text VARCHAR(100))")
} "create test table with auto increment column";

lives_ok {
    $dbi->insert(into => "test", values => { text => "Litfasssaeule" })
} "insert test data #1";
is $dbi->driver->last_auto_id($dbi), 1, "fetch last auto increment id #1";

lives_ok {
    $dbi->insert(into => "test", values => { text => "Stoffetzen" })
} "insert test data #2";
is $dbi->driver->last_auto_id($dbi), 2, "fetch last auto increment id #2";


done_testing;
