use strict;
use warnings;
use English;
use Test::More;
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
        [ 1, "Litfasssaeule", 5 ],
        [ 2, "Buergersteig",  3 ],
    ],
);

#
# tests
#
$db->run("SQL MERGE", 11, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $rownum;

    # update existing row
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { text => "Digital Signage" },
            where => { id => 1, entropy => "5" },
        );
        ok $rownum > 0; # MySQL returns 2 on update
    } "replace existing data";
    is_deeply $t->get_data, [
        [ 1, "Digital Signage", 5],
        [ 2, "Buergersteig",  3],
    ], "verify data";

    # update two values existing row
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { text => "Elektroschild", entropy => 27 },
            where => { id => 1 },
        );
        ok $rownum > 0; # MySQL returns 2 on update
    } "replace existing data (two values)";
    is_deeply $t->get_data, [
        [ 1, "Elektroschild", 27],
        [ 2, "Buergersteig",  3],
    ], "verify data";

    # insert new row
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { text => "Rathaus" },
            where => { id => 3, entropy => 42 },
        );
        is $rownum, 1;
    } "replace non-existing data (i.e. insert)";
    is_deeply $t->get_data, [
        [ 1, "Elektroschild", 27],
        [ 2, "Buergersteig",  3],
        [ 3, "Rathaus",       42],
    ], "verify data";

    # partly update row ignoring 'set_once'
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { text => "Saftladen" },
            set_once => { entropy => 50 },
            where => { id => 3 },
        );
        ok $rownum > 0;
    } "partly update row ignoring 'set_once'";
    is_deeply $t->get_data, [
        [ 1, "Elektroschild", 27],
        [ 2, "Buergersteig",  3],
        [ 3, "Saftladen",     42],
    ], "verify data";

    # insert new row obeying 'set_once'
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { text => "Schwimmhalle" },
            set_once => { entropy => 99 },
            where => { id => 4 },
        );
        is $rownum, 1;
    } "insert new row obeying 'set_once'";
    is_deeply $t->get_data, [
        [ 1, "Elektroschild", 27],
        [ 2, "Buergersteig",  3],
        [ 3, "Saftladen",     42],
        [ 4, "Schwimmhalle",  99],
    ], "verify data";

    # do not accept complex WHERE clause (as it also serves as source for insert values)
    dies_ok {
        $dbi->merge(
            table => "test",
            values => { text => "Rathaus" },
            where => { id => { '>=', 3 }, entropy => 42 },
        )
    } "do not allow complex WHERE clause";
});

done_testing($db->test_no);

