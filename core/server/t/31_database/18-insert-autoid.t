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
        [ 1, "Litfasssaeule", 333 ],
    ],
);

#
# tests
#
$db->run("SQL INSERT with automatic ID = sequence generation", 2, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $rownum;

    # correct insert
    lives_and {
        use OpenXPKI::Server::Database;

        $rownum = $dbi->insert(
            into => "test",
            values => { id => AUTO_ID, text => "Flatscreen", entropy => 10 },
        );
        ok $rownum == 1;
    } "correctly execute insert query";
    cmp_deeply $t->get_data, [
        [ 1,             "Litfasssaeule", 333 ],
        [ re(qr/^\d+$/), "Flatscreen",    10  ],
    ], "correct data after insert";
});

done_testing($db->test_no);

