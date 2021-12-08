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
$db->run("Transactions", 14, sub {
    my $t = shift;
    my $dbi = $t->dbi;

    #
    # correct transaction with commit
    #
    lives_ok { $dbi->start_txn } "start transaction";
    lives_and {
        $dbi->insert(
            into => "test",
            values => { id => 4, text => "Schwimmhalle" },
        );
        $dbi->commit;
        cmp_bag $t->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
            [ 4, "Schwimmhalle" ],
        ];
    } "insert a row";
    unlike $t->get_log, qr/transaction start/, "no negative log messages";

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
        cmp_bag $t->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
            [ 4, "Schwimmhalle" ],
        ];
    } "delete a row, but rollback";
    unlike $t->get_log, qr/transaction start/, "no negative log messages";

    #
    # commit without "transaction start"
    #
    lives_and {
        $dbi->delete(
            from => "test",
            where => { id => 4 },
        );
        $dbi->commit;
        cmp_bag $t->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
        ];
    } "delete a row + commit";
    like $t->get_log, qr/transaction start/, "warn about missing start_txn()";

    #
    # rollback without "transaction start"
    #
    lives_and {
        $dbi->delete(
            from => "test",
            where => { id => 3 },
        );
        $dbi->rollback;
        cmp_bag $t->get_data, [
            [ 1, "Litfasssaeule" ],
            [ 2, "Buergersteig" ],
            [ 3, "Rathaus" ],
        ];
    } "delete a row + rollback";
    like $t->get_log, qr/transaction start/, "warn about missing start_txn()";

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
        cmp_bag $t->get_data, [
            [ 1, "Litfasssaeule" ]
        ];
    } "start transaction twice, should be ignored";
    like $t->get_log, qr/running/, "warn about starting a transaction while another one is not finished";

    $t->dbi->disconnect;


    #
    # check if other DBI instance sees correct transaction (i.e. commit succeeded)
    #
    my $db_check = DatabaseTest->new(
        test_only => [ $t->type ],
        sqlite_db => $sqlite_db,
        columns => $columns,
    );

    $db_check->run("Data verification", 1, sub {
        my $t = shift;
        my $dbi = $t->dbi;

        cmp_bag $t->get_data, [
            [ 1, "Litfasssaeule" ],
        ], "correct data in other handle";
    });
});


done_testing($db->test_no);
