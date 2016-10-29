use strict;
use warnings;
use English;
use Test::More;
use Test::Exception;
use File::Spec::Functions qw( catfile catdir splitpath rel2abs );

my $basedir = catdir((splitpath(rel2abs(__FILE__)))[0,1]);

use_ok "OpenXPKI::Server::Database::Role::SequenceEmulation";
use_ok "OpenXPKI::Server::Database::Role::Driver";

#
# setup
#
use_ok "OpenXPKI::Server::Log";
my $log;
lives_ok { $log = OpenXPKI::Server::Log->new(CONFIG => catfile($basedir, "log4perl.conf")) };

#
# database driver classes
#
package OpenXPKI::Server::Database::Driver::Oxitestdb;
use Moose;
with 'OpenXPKI::Server::Database::Role::SequenceEmulation';
with 'OpenXPKI::Server::Database::Role::Driver';
sub dbi_driver { 'SQLite' }
sub dbi_dsn { my $self = shift; sprintf("dbi:%s:dbname=%s", $self->dbi_driver, $self->name) }
sub dbi_connect_params { }
sub sqlam_params { limit_offset => 'LimitOffset' }
sub last_auto_id { 1; } # dummy
__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::Database::Driver::OxitestdbList;
use Moose; extends 'OpenXPKI::Server::Database::Driver::Oxitestdb';
sub dbi_connect_params { private_Key => 'ToMyHeart' }

package OpenXPKI::Server::Database::Driver::OxitestdbHashref;
use Moose; extends 'OpenXPKI::Server::Database::Driver::Oxitestdb';
sub dbi_connect_params { { private_Key => 'ToMyHeart' } }

package OpenXPKI::Server::Database::Driver::OxitestdbArrayref;
use Moose; extends 'OpenXPKI::Server::Database::Driver::Oxitestdb';
sub dbi_connect_params { [] }

package main;

#
# tests
#
use_ok("OpenXPKI::Server::Database");

my $dbi;

lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log, db_params => { type => "Oxitestdb", name => ":memory:" },
) } "driver Oxitestdb - dbi instance";
lives_ok { $dbi->dbh } "driver Oxitestdb - process dbi_connect_params (undef)";

lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log, db_params => { type => "OxitestdbHashref", name => ":memory:" },
) } "driver OxitestdbHashref - dbi instance";
lives_and { is $dbi->dbh->{private_Key}, 'ToMyHeart' } "driver OxitestdbHashref - process dbi_connect_params (HashRef)";

lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log, db_params => { type => "OxitestdbList", name => ":memory:" },
) } "driver OxitestdbList - dbi instance";
lives_and { is $dbi->dbh->{private_Key}, 'ToMyHeart' } "driver OxitestdbList - process dbi_connect_params (list)";

lives_ok { $dbi = OpenXPKI::Server::Database->new(
    log => $log, db_params => { type => "OxitestdbArrayref", name => ":memory:" },
) } "driver OxitestdbArrayref - dbi instance";
throws_ok { $dbi->dbh } qr/dbi_connect_params/, "driver OxitestdbArrayref - complain about wrong dbi_connect_params";

done_testing;
