use strict;
use warnings;
use Test::More;
use English;
plan tests => 20;

use_ok('OpenXPKI::Debug');

diag "Use without specifying package name";
# check that everything works the same without specifying our name in
# use OpenXPKI::Debug ...
my $stderr = `perl -It/08_debug t/08_debug/main.pl TestModuleUseWithout.pm 1 2>&1`;
ok(! $CHILD_ERROR, 'main.pl execution');
like($stderr,
     qr{ ^\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2} }xms,
     'Debug message cotains a date and time'
);
like($stderr, qr{ DEBUG:1 }xms, 'Debug contains DEBUG:1 string');
unlike($stderr, qr{ DEBUG:2 }xms, 'Debug does not contain DEBUG:2 string');
like($stderr,
     qr{ TestModuleUseWithout::START }xms,
     'Debug contains module name and method'
 );
like($stderr, qr{ loglevel\ 1 }xms, 'Debug contains literal log message');
like($stderr, qr{ code:\ 2 }xms, 'Debug contains executed log message');

# debug level 16
$stderr = `perl -It/08_debug t/08_debug/main.pl TestModuleUseWithout.pm 16 2>&1`;
ok(! $CHILD_ERROR, 'main.pl execution');
like($stderr,
     qr{ ^\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2} }xms,
     'Debug message cotains a date and time'
);
like($stderr, qr{ DEBUG:1 }xms, 'Debug contains DEBUG:1 string');
like($stderr, qr{ DEBUG:2 }xms, 'Debug contains DEBUG:2 string');
like($stderr, qr{ DEBUG:16 }xms, 'Debug contains DEBUG:16 string');
unlike($stderr, qr{ DEBUG:32000 }xms, 'Debug does not contain DEBUG:32000 string');
like($stderr,
     qr{ TestModuleUseWithout::START }xms,
     'Debug contains module name and method'
 );
like($stderr, qr{ loglevel\ 1 }xms, 'Debug contains literal log message');
like($stderr, qr{ loglevel\ 2 }xms, 'Debug contains literal log message');
like($stderr, qr{ loglevel\ 4 }xms, 'Debug contains literal log message');
like($stderr, qr{ loglevel\ 16 }xms, 'Debug contains literal log message');
like($stderr, qr{ code:\ 2 }xms, 'Debug contains executed log message');

1;
