package TestModuleUseWithout;
use OpenXPKI -class_std;

use OpenXPKI::Debug;
$OpenXPKI::Debug::USE_COLOR = 1;

sub START {
    ##! 1: 'loglevel 1'
    ##! 2: 'loglevel 2'
    ##! 4: 'loglevel 4'
    ##! 16: 'loglevel 16'
    ##! 256: 'loglevel 256'
    print "new()\n";
    return 1;
}

sub foo {
    ##! 1: 'code: ' . (1 + 1)
    print "foo()\n";
    return 1;
}

1;
