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
        [ 1, "Litfasssaeule", 1 ],
        [ 2, "Buergersteig",  1 ],
        [ 3, "Rathaus",       42 ],
        [ 4, "Kindergarten",  3 ],
    ],
);

#
# tests
#
$db->run("SQL UPDATE", 3, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $rownum;

    # no update with non-matching where clause
    lives_and {
        $rownum = $dbi->update(
            table => "test",
            set => { entropy => 10 },
            where => { entropy => 99 },
        );
        ok $rownum == 0;
    } "no update with non-matching where clause";

    # simple update
    lives_and {
        $rownum = $dbi->update(
            table => "test",
            set => { entropy => 5 },
            where => { entropy => 1 },
        );
        is $rownum, 2;
    } "update 2 rows";

    # check data
    is_deeply $t->get_data, [
        [ 1, "Litfasssaeule", 5 ],
        [ 2, "Buergersteig",  5 ],
        [ 3, "Rathaus",       42 ],
        [ 4, "Kindergarten",  3 ],
    ], "correct data after update";
});

done_testing($db->test_no);
