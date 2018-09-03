#!/usr/bin/perl
use strict;
use warnings;
use English;
use OpenXPKI::Control;

exit OpenXPKI::Control::start({ SILENT => 1, DEBUG_BITMASK =>  0 });

