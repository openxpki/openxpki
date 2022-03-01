use strict;
use warnings;
use English;
use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw/ tempfile /;
use FindBin qw( $Bin );

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 100;

#
# setup
#
require "$Bin/DatabaseTest.pm";

my $columns = [ # yes an ArrayRef to have a defined order!
    id => "INTEGER PRIMARY KEY",
    text => "VARCHAR(100)",
];
my (undef, $sqlite_db) = tempfile(UNLINK => 1);
`sqlite3 $sqlite_db "PRAGMA journal_mode = WAL"`; # switch SQLite db to WAL mode

my $db = DatabaseTest->new(
    sqlite_db => $sqlite_db,
    columns => $columns,
    data => [
        [ 1, "Litfasssaeule" ],
        [ 2, "Buergersteig" ],
        [ 3, "Rathaus" ],
    ],
);

#
# tests
#
$db->run("Transactions", 16, sub {
    my ($t1, $t2) = @_;
    my $dbi = $t1->dbi;

    #
    # correct transaction with commit
    #
    lives_ok { $dbi->start_txn } "start transaction";

    lives_ok {
        $dbi->insert(
            into => "test",
            values => { id => 4, text => "Schwimmhalle" },
        );
    } "insert row";

    # check with second DBI instance
    SKIP: {
        skip "concurrent access not possible with SQLite", 1 if $t1->type eq 'sqlite';
        cmp_bag $t2->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
        ], "inserted row not visible yet in second DBI handle";
    }

    lives_and {
        $dbi->commit;
        cmp_bag $t1->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
            [ 4, "Schwimmhalle" ],
        ];
    } "inserted row visible after commit";

    # check with second DBI instance
    SKIP: {
        skip "concurrent access not possible with SQLite", 1 if $t1->type eq 'sqlite';
        cmp_bag $t2->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
            [ 4, "Schwimmhalle" ],
        ], "inserted row visible in second DBI handle after commit";
    }

    unlike $t1->get_log, qr/transaction start/, "no negative log messages";

    #
    # correct transaction with rollback
    #
    lives_ok { $dbi->start_txn } "start transaction";
    lives_and {
        $dbi->delete(
            from => "test",
            where => { id => 4 },
        );
        $dbi->rollback;
        cmp_bag $t1->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
            [ 4, "Schwimmhalle" ],
        ];
    } "delete a row, but rollback";
    unlike $t1->get_log, qr/transaction start/, "no negative log messages";

    #
    # commit without "transaction start"
    #
    lives_and {
        $dbi->delete(
            from => "test",
            where => { id => 4 },
        );
        $dbi->commit;
        cmp_bag $t1->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
        ];
    } "delete a row + commit";
    like $t1->get_log, qr/transaction start/, "warn about missing start_txn()";

    #
    # rollback without "transaction start"
    #
    lives_and {
        $dbi->delete(
            from => "test",
            where => { id => 3 },
        );
        $dbi->rollback;
        cmp_bag $t1->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
        ];
    } "delete a row + rollback";
    like $t1->get_log, qr/transaction start/, "warn about missing start_txn()";

    #
    # start transaction while other not finished
    #
    lives_and {
        # transaction #1
        $dbi->start_txn;
        $dbi->delete(
            from => "test",
            where => { id => 2 },
        );
        # transaction #2
        $dbi->start_txn;
        $dbi->delete(
            from => "test",
            where => { id => 3 },
        );
        $dbi->commit;
        cmp_bag $t1->get_data, [
            [ 1, "Litfasssaeule" ]
        ];
    } "start transaction twice, should be ignored";
    like $t1->get_log, qr/running/, "warn about starting a transaction while another one is not finished";

    $t1->dbi->disconnect;

    # check with second DBI instance
    cmp_bag $t2->get_data, [
        [ 1, "Litfasssaeule" ],
    ], "correct data in other DBI handle";
});


done_testing($db->test_no);
