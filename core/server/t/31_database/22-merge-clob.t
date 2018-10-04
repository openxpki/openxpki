use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use FindBin qw( $Bin );

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 100;

#
# Oracle shows a special behaviour where values <= 4000 bytes are casted to
# VARCHAR and bigger values to LONG.
# As our database layer's merge method used "SELECT ... FROM dual" in the Oracle
# driver and failed we have to take care that also large values are merged
# correctly.
#

#
# setup
#
require "$Bin/DatabaseTest.pm";

my $db = DatabaseTest->new(
    columns => [ # yes an ArrayRef to have a defined order!
        id => "INTEGER PRIMARY KEY",
        data => "CLOB", # Oracle-only data type, so we have to restrict test to Oracle
    ],
    data => [
        [ 1, "chirpychirpycheepcheepchirp" ],
    ],
    test_only => ['oracle'],
);

#
# tests
#
$db->run("SQL MERGE", 8, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $rownum;

    my $bigdata = pack("c*", (97) x 10000);

    # update existing row with small value
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { data => "soundofsilence" },
            where => { id => 1 },
        );
        ok $rownum > 0; # MySQL returns 2 on update
    } "replace existing data" or BAIL_OUT;
    is_deeply $t->get_data, [
        [ 1, "soundofsilence" ],
    ], "verify data";

    # update existing row with big value
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { data => $bigdata },
            where => { id => 1 },
        );
        ok $rownum > 0; # MySQL returns 2 on update
    } "replace existing data with 10000 character value" or BAIL_OUT;
    is_deeply $t->get_data, [
        [ 1, $bigdata ],
    ], "verify data";

     # insert new row with small value
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { data => "autobahn" },
            where => { id => 2 },
        );
        is $rownum, 1;
    } "replace non-existing data (i.e. insert)" or BAIL_OUT;
    is_deeply $t->get_data, [
        [ 1, $bigdata ],
        [ 2, "autobahn" ],
    ], "verify data";

     # insert new row with big value
    lives_and {
        $rownum = $dbi->merge(
            into => "test",
            set => { data => $bigdata },
            where => { id => 3 },
        );
        is $rownum, 1;
    } "replace non-existing data (i.e. insert 10000 character value)" or BAIL_OUT;
    is_deeply $t->get_data, [
        [ 1, $bigdata ],
        [ 2, "autobahn" ],
        [ 3, $bigdata ],
    ], "verify data";

});

done_testing($db->test_no);

