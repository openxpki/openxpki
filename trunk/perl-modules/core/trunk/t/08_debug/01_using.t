use strict;
use warnings;
use Test::More;
use English;
plan tests => 18;

use_ok('OpenXPKI::Debug');

diag "Standard debug usage";
my $stderr = `perl -It/08_debug t/08_debug/main.pl TestModule.pm 1 2>&1`;
ok(! $CHILD_ERROR, 'main.pl execution');
like($stderr,
     qr{ ^\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2} }xms,
     'Debug message cotains a date and time'
);
like($stderr, qr{ DEBUG:1 }xms, 'Debug contains DEBUG:1 string');
unlike($stderr, qr{ DEBUG:2 }xms, 'Debug does not contain DEBUG:2 string');
like($stderr,
     qr{ TestModule::START }xms,
     'Debug contains module name and method'
 );
like($stderr, qr{ loglevel\ 1 }xms, 'Debug contains literal log message');
like($stderr, qr{ code:\ 2 }xms, 'Debug contains executed log message');

# debug level 2
$stderr = `perl -It/08_debug t/08_debug/main.pl TestModule.pm 2 2>&1`;
ok(! $CHILD_ERROR, 'main.pl execution');
like($stderr,
     qr{ ^\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2} }xms,
     'Debug message cotains a date and time'
);
like($stderr, qr{ DEBUG:1 }xms, 'Debug contains DEBUG:1 string');
like($stderr, qr{ DEBUG:2 }xms, 'Debug contains DEBUG:2 string');
unlike($stderr, qr{ DEBUG:16 }xms, 'Debug does not contain DEBUG:16 string');
like($stderr,
     qr{ TestModule::START }xms,
     'Debug contains module name and method'
 );
like($stderr, qr{ loglevel\ 1 }xms, 'Debug contains literal log message');
like($stderr, qr{ loglevel\ 2 }xms, 'Debug contains literal log message');
unlike($stderr, qr{ loglevel\ 4 }xms, 'Debug contains literal log message');
like($stderr, qr{ code:\ 2 }xms, 'Debug contains executed log message');

1;
