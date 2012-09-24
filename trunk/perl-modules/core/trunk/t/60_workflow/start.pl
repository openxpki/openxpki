#!/usr/bin/perl
use strict;
use warnings;
use English;
use OpenXPKI::Control;

my $ret = OpenXPKI::Control::start({ SILENT => 1, DEBUG =>  0 });
exit ($ret != 1);
