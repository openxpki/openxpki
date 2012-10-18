package TestModule;

use strict;
use warnings;

use OpenXPKI::Debug 'TestModule';
use Class::Std;

sub START {
    ##! 1: 'loglevel 1'
    ##! 2: 'loglevel 2'
    ##! 4: 'loglevel 4'
    ##! 16: 'loglevel 16'
    ##! 32000: 'loglevel 32000'
    print "new()\n";
    return 1;
}

sub foo {
    ##! 1: 'code: ' . (1 + 1)
    print "foo()\n";
    return 1;
}

1;
