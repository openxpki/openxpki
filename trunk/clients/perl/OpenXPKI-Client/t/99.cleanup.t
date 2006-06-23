use Test::More tests => 1;
use File::Path;
use File::Spec;
use English;

use strict;
use warnings;

our %config;
require 't/common.pl';

diag("Cleaning up");

diag "Stopping OpenXPKI Server.";
ok(system("openxpkictl --config $config{config_file} stop") == 0);
# leaving this intact for debugging
#ok(rmtree($config{server_dir}));
