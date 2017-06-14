use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

#
# setup
#
my $log = Log::Log4perl->get_logger;

use_ok("OpenXPKI::Server::Database");
my $dbi;
lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log,
    db_params => { type => "SQLite", name => ":memory:" },
) } "dbi instance";

#
# tests
#
my $builder;
lives_ok { $builder = $dbi->query_builder } "fetch query builder object";

my $sql;

# LIMIT ... OFFSET
lives_ok {
    $sql = $builder->select(
        from => 'flora',
        columns => [ qw ( name color ) ],
        where => { fruits => 'forbidden' },
        limit => 5,
        offset => 10,
    )->string
} "create SELECT query with LIMIT and OFFSET";

like $sql,
    qr/ ^
        SELECT \W+ name, \W+ color \W+
        FROM \W+ flora \W
        WHERE .*
        LIMIT .* OFFSET
    /xmsi, "correct SQL string";

# JOIN
lives_ok {
    $sql = $builder->select(
        from_join => 'fruit id=id flora',
        columns => [ qw ( name color ) ],
        where => { fruits => 'forbidden' },
    )->string
} "create SELECT query with JOIN";


like $sql,
    qr/ ^
        SELECT \W+ name, \W+ color \W+
        FROM \W+ fruit \W
        .*? JOIN \W+ flora \W+
        ON \W+ fruit\.id \W+ = \W+ flora\.id \W+
        WHERE
    /xmsi, "correct SQL string";

done_testing;
