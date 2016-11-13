use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use File::Spec::Functions qw( catdir splitpath rel2abs );

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 2;

#
# setup
#
my $basedir = catdir((splitpath(rel2abs(__FILE__)))[0,1]);
require "$basedir/DatabaseTest.pm";

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
$db->run("SQL MERGE", 6, sub {
    my $t = shift;
    my $dbi = $t->dbi;

    # update existing row
    lives_and {
        $dbi->merge(
            into => "test",
            set => { text => "Digital Signage" },
            where => { id => 1, entropy => "5" },
        );
        is_deeply $t->get_data, [
            [ 1, "Digital Signage", 5],
            [ 2, "Buergersteig",  3],
        ];
    } "replace existing data";

    # update two values existing row
    lives_and {
        $dbi->merge(
            into => "test",
            set => { text => "Elektroschild", entropy => 27 },
            where => { id => 1 },
        );
        is_deeply $t->get_data, [
            [ 1, "Elektroschild", 27],
            [ 2, "Buergersteig",  3],
        ];
    } "replace existing data (two values)";

    # insert new row
    lives_and {
        $dbi->merge(
            into => "test",
            set => { text => "Rathaus" },
            where => { id => 3, entropy => 42 },
        );
        is_deeply $t->get_data, [
            [ 1, "Elektroschild", 27],
            [ 2, "Buergersteig",  3],
            [ 3, "Rathaus",       42],
        ];
    } "replace non-existing data (i.e. insert)";

    # partly update row ignoring 'set_once'
    lives_and {
        $dbi->merge(
            into => "test",
            set => { text => "Saftladen" },
            set_once => { entropy => 50 },
            where => { id => 3 },
        );
        is_deeply $t->get_data, [
            [ 1, "Elektroschild", 27],
            [ 2, "Buergersteig",  3],
            [ 3, "Saftladen",     42],
        ];
    } "partly update row ignoring 'set_once'";

    # insert new row obeying 'set_once'
    lives_and {
        $dbi->merge(
            into => "test",
            set => { text => "Schwimmhalle" },
            set_once => { entropy => 99 },
            where => { id => 4 },
        );
        is_deeply $t->get_data, [
            [ 1, "Elektroschild", 27],
            [ 2, "Buergersteig",  3],
            [ 3, "Saftladen",     42],
            [ 4, "Schwimmhalle",  99],
        ];
    } "insert new row obeying 'set_once'";

    # do not accept complex WHERE clause (as it also serves as source for insert values)
    dies_ok {
        $dbi->replace(
            table => "test",
            values => { text => "Rathaus" },
            where => { id => { '>=', 3 }, entropy => 42 },
        )
    } "do not allow complex WHERE clause";
});

done_testing($db->test_no);

