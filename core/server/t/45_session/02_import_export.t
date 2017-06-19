use strict;
use warnings;

# Core modules
use File::Temp qw( tempdir );
use English;

# CPAN modules
use Test::More;
use Test::Exception;

plan tests => 8;

use_ok "OpenXPKI::Server::Session";

my $session_dir = tempdir( CLEANUP => 1 );

## create new session
my ($session, $session2);
lives_ok {
    $session =  OpenXPKI::Server::Session->new({ DIRECTORY => $session_dir, LIFETIME  => 2 });
    $session2 = OpenXPKI::Server::Session->new({ DIRECTORY => $session_dir, LIFETIME  => 2 });
} "create session 1 and 2";

lives_ok { $session->data->user("dummy") }                "set user";
lives_ok { $session->data->role("dancer") }               "set role";
my $info;
lives_ok { $info = $session->export_serialized_info }   "export serialized data from session 1";
lives_ok { $session2->import_serialized_info($info) }   "import serialized data into session 2";
is $session2->get_user, "dummy",  "user was correctly imported";
is $session2->get_role, "dancer", "role was correctly imported";

1;
