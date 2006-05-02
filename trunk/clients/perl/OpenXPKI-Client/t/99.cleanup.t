use Test::More tests => 2;
use File::Path;
use File::Spec;
use English;

use strict;
use warnings;

our %config;
require 't/common.pl';

diag("Cleaning up");

diag "Stopping OpenXPKI Server.";
ok(system("$config{server_dir}/bin/openxpkictl stop") == 0);
ok(rmtree($config{target_dir}));

