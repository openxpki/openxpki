use Test::More tests => 1;
use English;

use POSIX ":sys_wait_h";
use Errno;

use strict;
use warnings;

our %config;
require 't/common.pl';

diag("SCEP Client Test: cleanup");

ok(system("rm -r t/instance") == 0);
