package OpenXPKI::Server::Database::Driver::MySQLTest;
use Moose;
extends 'OpenXPKI::Server::Database::Driver::MySQL';

around 'dbi_dsn' => sub {
    my $orig = shift;
    my $self = shift;
    return $self->$orig(@_) . ";mysql_read_timeout=1";
};


package main;

use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 100;

plan skip_all => "No MySQL database found / OXI_TEST_DB_MYSQL_NAME not set" unless $ENV{OXI_TEST_DB_MYSQL_NAME};

#
# setup
#
use_ok "OpenXPKI::Server::Database";
use_ok "OpenXPKI::Server::Log";
my $log = OpenXPKI::Server::Log->new(
    CONFIG => \"
# Catch-all root logger
log4perl.rootLogger = DEBUG, Everything

log4perl.appender.Everything          = Log::Log4perl::Appender::String
log4perl.appender.Everything.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Everything.layout.ConversionPattern = %d %c.%p %m%n
"
);

my $db_params = {
    type => "MySQLTest",
    host => "127.0.0.1", # if not specified, the driver tries socket connection
    name => $ENV{OXI_TEST_DB_MYSQL_NAME},
    user => $ENV{OXI_TEST_DB_MYSQL_USER},
    passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
};

my $db_alice = OpenXPKI::Server::Database->new(log => $log, db_params => $db_params);
my $db_bob   = OpenXPKI::Server::Database->new(log => $log, db_params => $db_params);

#
# create test table
#
eval { $db_alice->run("DROP TABLE test") };
$db_alice->start_txn;
$db_alice->run("CREATE TABLE test (id INTEGER PRIMARY KEY, text VARCHAR(100))");
$db_alice->insert(into => "test", values => { id => 1, text => "Litfasssaeule" });
$db_alice->insert(into => "test", values => { id => 2, text => "Buergersteig" });
$db_alice->insert(into => "test", values => { id => 3, text => "Rathaus" });
$db_alice->commit;

#
# Tests
#
my $data;

# Writing and reading
lives_ok {
    $db_alice->start_txn;
    $db_alice->update(table => "test", set => { text => "LED-Panel" }, where => { id => 1 });
} "Test 1: Alice starts an update transaction";

lives_and {
    $data = $db_bob->select_one(from => "test", columns => [ "id", "text" ], where => { id => 1 });
    is_deeply $data, { id => 1, text => "Litfasssaeule" };
} "Test 1: Bob still sees old data";

lives_ok {
    $db_alice->commit;
} "Test 1: Alice commits transaction";

lives_and {
    $data = $db_bob->select_one(from => "test", columns => [ "id", "text" ], where => { id => 1 });
    is_deeply $data, { id => 1, text => "LED-Panel" };
} "Test 1: Bob sees Alices new data";

# Two instances writing
lives_ok {
    $db_alice->start_txn;
    $db_alice->update(table => "test", set => { text => "Shopping-Meile" }, where => { id => 2 });
} "Test 2: Alice starts another update transaction";

lives_ok {
    $db_bob->start_txn;
} "Test 2: Bob starts a transaction";

dies_ok {
    $db_bob->update(table => "test", set => { text => "Marktgasse" }, where => { id => 2 });
} "Test 2: Bob fails trying to update the same row (MySQL lock)";

lives_and {
    $data = $db_bob->select_one(from => "test", columns => [ "id", "text" ], where => { id => 2 });
    is_deeply $data, { id => 2, text => "Buergersteig" };
} "Test 2: Bob still sees old data";

lives_ok {
    $db_alice->commit;
} "Test 2: Alice commits transaction";

lives_and {
    $data = $db_bob->select_one(from => "test", columns => [ "id", "text" ], where => { id => 2 });
    is_deeply $data, { id => 2, text => "Shopping-Meile" };
} "Test 2: Bob sees Alices new data";

$db_bob->commit; # to be able to drop database
$db_alice->run("DROP TABLE test");

done_testing(12);
