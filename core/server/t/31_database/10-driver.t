use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);


use_ok "OpenXPKI::Database::Role::SequenceEmulation";
use_ok "OpenXPKI::Database::Role::Driver";

#
# setup
#
my $log = Log::Log4perl->get_logger;

#
# database driver classes
#
package OpenXPKI::Database::Driver::Oxitestdb;
use Moose;
with 'OpenXPKI::Database::Role::MergeEmulation';
with 'OpenXPKI::Database::Role::SequenceEmulation';
with 'OpenXPKI::Database::Role::CountEmulation';
with 'OpenXPKI::Database::Role::Driver';
sub dbi_driver { 'SQLite' }
sub dbi_dsn { my $self = shift; sprintf("dbi:%s:dbname=%s", $self->dbi_driver, $self->name) }
sub dbi_attrs { }
sub perform_checks { }
sub on_connect { }
sub sqlam_params { limit_offset => 'LimitOffset' }
sub last_auto_id { 1; } # dummy
sub sql_autoinc_column { return "INTEGER PRIMARY KEY AUTOINCREMENT" }
sub table_drop_query { }
sub do_sql_replacements { shift; shift }
__PACKAGE__->meta->make_immutable;

package OpenXPKI::Database::Driver::OxitestdbList;
use Moose; extends 'OpenXPKI::Database::Driver::Oxitestdb';
sub dbi_attrs { private_Key => 'ToMyHeart' }

package OpenXPKI::Database::Driver::OxitestdbHashref;
use Moose; extends 'OpenXPKI::Database::Driver::Oxitestdb';
sub dbi_attrs { { private_Key => 'ToMyHeart' } }

package OpenXPKI::Database::Driver::OxitestdbArrayref;
use Moose; extends 'OpenXPKI::Database::Driver::Oxitestdb';
sub dbi_attrs { [] }

package main;

#
# tests
#
use_ok("OpenXPKI::Database");

my $dbi;

lives_ok { $dbi = OpenXPKI::Database->new(
    log => $log, db_params => { type => "Oxitestdb", name => ":memory:" },
) } "driver Oxitestdb - dbi instance";
lives_ok { $dbi->dbh } "driver Oxitestdb - process dbi_attrs (undef)";

lives_ok { $dbi = OpenXPKI::Database->new(
    log => $log, db_params => { type => "OxitestdbHashref", name => ":memory:" },
) } "driver OxitestdbHashref - dbi instance";
lives_and { is $dbi->dbh->{private_Key}, 'ToMyHeart' } "driver OxitestdbHashref - process dbi_attrs (HashRef)";

lives_ok { $dbi = OpenXPKI::Database->new(
    log => $log, db_params => { type => "OxitestdbList", name => ":memory:" },
) } "driver OxitestdbList - dbi instance";
lives_and { is $dbi->dbh->{private_Key}, 'ToMyHeart' } "driver OxitestdbList - process dbi_attrs (list)";

lives_ok { $dbi = OpenXPKI::Database->new(
    log => $log, db_params => { type => "OxitestdbArrayref", name => ":memory:" },
) } "driver OxitestdbArrayref - dbi instance";
throws_ok { $dbi->dbh } qr/dbi_attrs/, "driver OxitestdbArrayref - complain about wrong dbi_attrs";

done_testing;
