use strict;
use warnings;
use English;
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use FindBin qw( $Bin );

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 100;

#
# setup
#
require "$Bin/DatabaseTest.pm";

my $db = DatabaseTest->new(
    columns => [ # yes an ArrayRef to have a defined order!
        id => "INTEGER PRIMARY KEY",
        text => "VARCHAR(100)",
        entropy => "INTEGER",
    ],
    data => [
        [ 1, "Litfasssaeule", 1 ],
        [ 2, "Buergersteig",  1 ],
        [ 3, "Rathaus",       42 ],
        [ 4, "Kindergarten",  3 ],
        [ 5, "Luft",          undef ],
    ],
);

#
# tests
#
$db->run("SQL SELECT", 10, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $sth;

    # simple select
    lives_and {
        $sth = $dbi->select(
            from => "test",
            columns => [ "text" ],
            where => { id => 3 },
        );
        is_deeply $sth->fetchall_arrayref, [
            [ "Rathaus" ],
        ];
    } "simple select";

    # select with AND
    lives_and {
        my $arrays = $dbi->select_arrays(
            from => "test",
            columns => [ "text" ],
            where => { text => "Litfasssaeule", entropy => 1 },
        );
        is_deeply $arrays, [
            [ "Litfasssaeule" ],
        ];
    } "select_arrays with AND";

    # select with OR
    lives_and {
        my $hashes = $dbi->select_hashes(
            from => "test",
            columns => [ "text" ],
            where => { entropy => [ 1, 42] },
        );
        is_deeply $hashes, [
            { text => "Litfasssaeule" },
            { text => "Buergersteig" },
            { text => "Rathaus" },
        ];
    } "select_hashes with OR";

    # select with OR
    lives_and {
        $sth = $dbi->select(
            from => "test",
            columns => [ "text" ],
            where => { entropy => [ 42, undef] },
        );
        is_deeply $sth->fetchall_arrayref, [
            [ "Rathaus" ],
            [ "Luft" ],
        ];
    } "select with OR and NULL";

    # select with "bigger than"
    lives_and {
        $sth = $dbi->select(
            from => "test",
            columns => [ "text" ],
            where => { id => { ">=", 3 } },
        );
        is_deeply $sth->fetchall_arrayref, [
            [ "Rathaus" ],
            [ "Kindergarten" ],
            [ "Luft" ],
        ];
    } "select with 'bigger than'";

    # select without result
    lives_and {
        my $one = $dbi->select_one(
            from => "test",
            columns => [ "text" ],
            where => { text => "Rathaus", entropy => 33 },
        );
        is_deeply $one, undef;
    } "select_one without result";

    # select from non existing table
    dies_ok {
        $sth = $dbi->select(
            from => "huh",
            columns => [ "text" ],
            where => { entropy => 33 },
        );
    } "select from non existing table";

    lives_ok { $dbi->rollback() } "rollback";

    # sub query
    lives_and {
        $sth = $dbi->select(
            from => "test",
            columns => [ "text" ],
            where => {
                id => $dbi->subselect(IN => {
                    from => "test",
                    columns => [ "id" ],
                    where => { text => [ "Rathaus", "Kindergarten" ] },
                }),
            },
        );
        is_deeply $sth->fetchall_arrayref, [
            [ "Rathaus" ],
            [ "Kindergarten" ],
        ];
    } "select with sub query";

    # select with literal WHERE clause
    lives_and {
        $sth = $dbi->select(
            from => "test",
            columns => [ "text" ],
            where => \"id >= 3",
        );
        is_deeply $sth->fetchall_arrayref, [
            [ "Rathaus" ],
            [ "Kindergarten" ],
            [ "Luft" ],
        ];
    } "select with literal WHERE clause";
});

done_testing($db->test_no);
