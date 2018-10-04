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
        [ 1, "Litfasssaeule", 333 ],
    ],
);

#
# tests
#
$db->run("SQL INSERT", 8, sub {
    my $t = shift;
    my $dbi = $t->dbi;
    my $rownum;

    # specify wrong method parameters
    throws_ok {
        $dbi->insert(
            dummytestparameter => "test",
            values => { id => 1, text => "Flatscreen", entropy => 10 },
        );
    } "OpenXPKI::Exception", "fail if wrong method parameters are given";
    like $@, qr/(dummytestparameter)/i, "return correct error message";

    # specify wrong column name, should complain
    throws_ok {
        $dbi->insert(
            into => "test",
            values => { id => 2, dummytestcolumn => "Flatscreen", entropy => 10 },
        );
    } "OpenXPKI::Exception", "fail to insert wrong column name";
    like $@, qr/dummytestcolumn/i, "return correct error message";

    # insert duplicate primary key, should complain
    throws_ok {
        $dbi->insert(
            into => "test",
            values => { id => 1, text => "Flatscreen", entropy => 10 },
        );
    } "OpenXPKI::Exception", "fail to insert duplicate primary key";
    like $@, qr/(unique|duplicate)/i, "return correct error message";

    # correct insert
    lives_and {
        $rownum = $dbi->insert(
            into => "test",
            values => { id => 2, text => "Flatscreen", entropy => 10 },
        );
        ok $rownum == 1;
    } "correctly execute insert query";
    is_deeply $t->get_data, [
        [ 1, "Litfasssaeule", 333 ],
        [ 2, "Flatscreen",    10  ],
    ], "correct data after insert";
});

done_testing($db->test_no);
