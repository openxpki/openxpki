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
BAIL_OUT("aborted");
ok(system("openxpkictl --config $config{config_file} stop") == 0);
ok(rmtree($config{server_dir}));
