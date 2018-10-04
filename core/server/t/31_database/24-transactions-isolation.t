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
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 100;

plan skip_all => "No MySQL database found / OXI_TEST_DB_MYSQL_NAME not set" unless $ENV{OXI_TEST_DB_MYSQL_NAME};

#
# setup
#
use_ok "OpenXPKI::Server::Database";
my $log = Log::Log4perl->get_logger;

my $db_params = {
    type => "MySQLTest",
    host => "127.0.0.1", # if not specified, the driver tries socket connection
    name => $ENV{OXI_TEST_DB_MYSQL_NAME},
    user => $ENV{OXI_TEST_DB_MYSQL_USER},
    passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
};

my $db_alice = OpenXPKI::Server::Database->new(log => $log, db_params => $db_params);
my $db_bob   = OpenXPKI::Server::Database->new(log => $log, db_params => $db_params);

# Checks if db handle "bob" sees the given data in table "test"
sub bob_sees {
    my ($id, $text, $message) = @_;
    my $data;
    lives_and {
        $data = $db_bob->select_one(from => "test", columns => [ "id", "text" ], where => { id => $id });
        is_deeply $data, ($text ? { id => $id, text => $text } : undef);
    } $message;
}

#
# create test table
#
eval { $db_alice->run("DROP TABLE test") };
$db_alice->start_txn;
$db_alice->run("CREATE TABLE test (id INTEGER PRIMARY KEY, text VARCHAR(100))");
$db_alice->insert(into => "test", values => { id => 1, text => "Litfasssaeule" });
$db_alice->insert(into => "test", values => { id => 2, text => "Buergersteig" });
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

bob_sees 1, "Litfasssaeule", "Test 1: Bob still sees old data";

lives_ok {
    $db_alice->commit;
} "Test 1: Alice commits transaction";

bob_sees 1, "LED-Panel", "Test 1: Bob sees Alices new data";

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

bob_sees 2, "Buergersteig", "Test 2: Bob still sees old data";

lives_ok {
    $db_alice->commit;
} "Test 2: Alice commits transaction";

bob_sees 2, "Shopping-Meile", "Test 2: Bob sees Alices new data";

# Combined "query & commit" commands
lives_ok {
    $db_alice->insert_and_commit(into => "test", values => { text => "Hutladen", id => 3 });
} "Test 3: Alice runs an 'insert & commit' command";

bob_sees 3, "Hutladen", "Test 3: Bob sees Alices new data";

lives_ok {
    $db_alice->update_and_commit(table => "test", set => { text => "Basecap-Shop" }, where => { id => 3 });
} "Test 3: Alice runs an 'update & commit' command";

bob_sees 3, "Basecap-Shop", "Test 3: Bob sees Alices new data";

lives_ok {
    $db_alice->merge_and_commit(into => "test", set => { text => "Happy Hat" }, where => { id => 3 });
} "Test 3: Alice runs an 'merge & commit' command";

bob_sees 3, "Happy Hat", "Test 3: Bob sees Alices new data";

lives_ok {
    $db_alice->delete_and_commit(from => "test", where => { id => 3 });
} "Test 3: Alice runs an 'delete & commit' command";

bob_sees 3, undef, "Test 3: Bob sees Alices deletions";

$db_bob->commit; # to be able to drop database
$db_alice->run("DROP TABLE test");

done_testing();
