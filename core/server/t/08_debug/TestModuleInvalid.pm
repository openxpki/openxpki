package TestModuleInvalid;
use OpenXPKI -class_std;

use OpenXPKI::Debug 'TestModuleInvalid';
$OpenXPKI::Debug::USE_COLOR = 1;

sub START {
    ##! 1: 'loglevel 1'
    ##! 2: 'loglevel 2'
    ##! 4: 'loglevel 4'
    ##! invalid syntax one
    ##! 1: 'invalid syntax two
    ##! 2: 'calling an unknown method: ' . blafasel()
    ##! 4: 'calling something from an unknown package: ' . Nonsense::ThisDoesNotExist::bla()
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
