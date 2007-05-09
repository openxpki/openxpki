#!/usr/bin/perl 

use strict;
use warnings;

use OpenXPKI::Debug;
$OpenXPKI::Debug::LEVEL{'.*'} = $ARGV[1];

require "$ARGV[0]";

my $module_name = $ARGV[0];
$module_name =~ s/\.pm//;

my $mod = $module_name->new();
$mod->foo();

