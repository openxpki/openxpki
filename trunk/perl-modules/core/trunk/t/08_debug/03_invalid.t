use strict;
use warnings;
use Test::More;
use English;
plan tests => 24;

use_ok('OpenXPKI::Debug');

diag "Catching invalid debug output";
# first check that everything works with the invalid module
my $stderr = `perl -It/08_debug t/08_debug/main.pl TestModuleInvalid.pm 1 2>&1`;
ok(! $CHILD_ERROR, 'main.pl execution');
like($stderr,
     qr{ ^\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2} }xms,
     'Debug message cotains a date and time'
);
like($stderr, qr{ DEBUG:1 }xms, 'Debug contains DEBUG:1 string');
unlike($stderr, qr{ DEBUG:2 }xms, 'Debug does not contain DEBUG:2 string');
like($stderr,
     qr{ TestModuleInvalid::START }xms,
     'Debug contains module name and method'
 );
like($stderr, qr{ loglevel\ 1 }xms, 'Debug contains literal log message');
like($stderr, qr{ code:\ 2 }xms, 'Debug contains executed log message');

# debug level 16
$stderr = `perl -It/08_debug t/08_debug/main.pl TestModuleInvalid.pm 16 2>&1`;
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
     qr{ TestModuleInvalid::START }xms,
     'Debug contains module name and method'
 );
like($stderr, qr{ loglevel\ 1 }xms, 'Debug contains literal log message');
like($stderr, qr{ loglevel\ 2 }xms, 'Debug contains literal log message');
like($stderr, qr{ loglevel\ 4 }xms, 'Debug contains literal log message');
like($stderr, qr{ loglevel\ 16 }xms, 'Debug contains literal log message');
like($stderr, qr{ code:\ 2 }xms, 'Debug contains executed log message');

# here are the invalidity specific tests ...
like($stderr, qr{ Invalid\ DEBUG\ statement }xms, 'Invalid debug statement caught');
like($stderr, qr{ Invalid\ DEBUG\ statement: .* Can't\ find\ string\ terminator }xms, 'Unclosed string caught');
like($stderr, qr{ Invalid\ DEBUG\ statement: .* Can't\ locate\ class\ method }xms, 'Unknown method caught');
like($stderr, qr{ Invalid\ DEBUG\ statement: .* Undefined\ subroutine }xms, 'Unknown package caught');

1;
