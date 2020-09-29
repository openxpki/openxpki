use strict;
use warnings;
use English;
use Test::More;
use Test::Deep;
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
$db->run("SQL COUNT", 4, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $num;

    # simple select
    lives_and {
        $num = $dbi->count(
            from => "test",
            columns => [ "text" ],
            where => { id => 3 },
        );
        is $num, 1;
    } "simple select";

    # select with OR
    lives_and {
        $num = $dbi->count(
            from => "test",
            columns => [ "text" ],
            where => { entropy => [ 42, undef] },
        );
        is $num, 2;
    } "select with OR and NULL";

    # select without result
    lives_and {
        $num = $dbi->count(
            from => "test",
            columns => [ "text" ],
            where => { text => "Rathaus", entropy => 33 },
        );
        is $num, 0;
    } "select without result";

    lives_and {
        $num = $dbi->count(
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
        is $num, 2;
    } "select with sub query";
});

done_testing($db->test_no);
