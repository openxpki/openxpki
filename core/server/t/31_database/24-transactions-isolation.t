package main;

use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use File::Temp qw/ tempfile /;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

use FindBin qw( $Bin );
use OpenXPKI::Server::Database;
require "$Bin/DatabaseTest.pm";

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 100;

#
# setup
#
my $log = Log::Log4perl->get_logger;

# Checks if given db handle sees the given data in table "test"
sub handle_sees {
    my ($dbh, $id, $text, $message) = @_;
    my $data;
    lives_and {
        $data = $dbh->select_one(from => "test", columns => [ "id", "text" ], where => { id => $id });
        is_deeply $data, ($text ? { id => $id, text => $text } : undef);
    } $message;
}

my (undef, $sqlite_db) = tempfile(UNLINK => 1);
`sqlite3 $sqlite_db "PRAGMA journal_mode = WAL"`; # switch SQLite db to WAL mode

my $tests = [
    {
        db_params => {
            %{ DatabaseTest->new->get_dbi_params('sqlite') },
            name => $sqlite_db,
        }
    },
    {
        env_var => 'OXI_TEST_DB_MYSQL_NAME',
        db_params => DatabaseTest->new->get_dbi_params('mariadb'),
    },
];

for my $test (@{$tests}) {
    my $env_var = $test->{env_var};
    my $db_params = $test->{db_params};

    my $db_alice = OpenXPKI::Server::Database->new(log => $log, db_params => $db_params);
    my $db_bob   = OpenXPKI::Server::Database->new(log => $log, db_params => $db_params);

    SKIP: {
        skip "$env_var not set", 1 if ($env_var and not $ENV{$env_var});

        subtest $db_params->{type} => sub {
            my $is_sqlite = $db_params->{type} =~ /^sqlite/i;

            #
            # create test table
            #
            eval { $db_alice->drop_table("test") };
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

            handle_sees $db_bob, 1, "Litfasssaeule", "Test 1: Bob still sees old data";

            lives_ok {
                $db_alice->commit;
            } "Test 1: Alice commits transaction";

            $db_bob->commit if $is_sqlite; # SQLite defaults to REPEATABLE READ isolation level, i.e. only a new txn sees the updated data
            handle_sees $db_bob, 1, "LED-Panel", "Test 1: Bob sees Alices new data";

            # Two instances writing
            lives_ok {
                $db_alice->start_txn;
                $db_alice->update(table => "test", set => { text => "Shopping-Meile" }, where => { id => 2 });
            } "Test 2: Alice starts another update transaction";

            lives_ok {
                $db_bob->start_txn;
            } "Test 2: Bob starts a transaction";

            throws_ok {
                $db_bob->update(table => "test", set => { text => "Marktgasse" }, where => { id => 2 });
            } qr/ lock /msxi, "Test 2: Bob fails trying to update the same row (row lock)";

            handle_sees $db_bob, 2, "Buergersteig", "Test 2: Bob still sees old data";

            lives_ok {
                $db_alice->commit;
            } "Test 2: Alice commits transaction";

            $db_bob->commit if $is_sqlite;
            handle_sees $db_bob, 2, "Shopping-Meile", "Test 2: Bob sees Alices new data";

            # Combined "query & commit" commands
            lives_ok {
                $db_alice->insert_and_commit(into => "test", values => { text => "Hutladen", id => 3 });
            } "Test 3: Alice runs an 'insert & commit' command";

            $db_bob->commit if $is_sqlite;
            handle_sees $db_bob, 3, "Hutladen", "Test 3: Bob sees Alices new data";

            lives_ok {
                $db_alice->update_and_commit(table => "test", set => { text => "Basecap-Shop" }, where => { id => 3 });
            } "Test 3: Alice runs an 'update & commit' command";

            $db_bob->commit if $is_sqlite;
            handle_sees $db_bob, 3, "Basecap-Shop", "Test 3: Bob sees Alices new data";

            lives_ok {
                $db_alice->merge_and_commit(into => "test", set => { text => "Happy Hat" }, where => { id => 3 });
            } "Test 3: Alice runs an 'merge & commit' command";

            $db_bob->commit if $is_sqlite;
            handle_sees $db_bob, 3, "Happy Hat", "Test 3: Bob sees Alices new data";

            lives_ok {
                $db_alice->delete_and_commit(from => "test", where => { id => 3 });
            } "Test 3: Alice runs an 'delete & commit' command";

            $db_bob->commit if $is_sqlite;
            handle_sees $db_bob, 3, undef, "Test 3: Bob sees Alices deletions";

            $db_bob->commit; # to be able to drop database
            $db_alice->drop_table("test");
        }
    }
}

done_testing();
