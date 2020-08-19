use strict;
use warnings;

# Core modules
use Test::More;
use English;
use FindBin qw( $Bin );

plan tests => 3;

use_ok('OpenXPKI::Debug');

my $test = sub {
    my ($loglevel) = @_;
    # map desired loglevel to a bitmask
    my $bitmask = { 1 => 0b01, 16 => 0b11111, }->{$loglevel};

    plan tests => 6 + ($loglevel == 1 ? 2 : 12);

    my $stderr = `$^X -I$Bin $Bin/main.pl TestModuleInvalid.pm $bitmask 2>&1`;

    ok(! $CHILD_ERROR, 'main.pl execution');
    like($stderr,
         qr{ ^\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2} }xms,
         'date and time'
    );
    like($stderr, qr{ DEBUG:1 }xms, '"DEBUG:1" string');

    if ($loglevel == 1) {
        unlike($stderr, qr{ DEBUG:2 }xms, '"DEBUG:2" string should not be there');
    }
    else {
        like($stderr, qr{ DEBUG:2 }xms, '"DEBUG:2" string');
        like($stderr, qr{ DEBUG:4 }xms, '"DEBUG:4" string');
        like($stderr, qr{ DEBUG:16 }xms, '"DEBUG:16" string');
        unlike($stderr, qr{ DEBUG:256 }xms, '"DEBUG:256" string should not be there');
    }

    like($stderr, qr{ TestModuleInvalid::START }xms, 'module name and method');
    like($stderr, qr{ loglevel\ 1 }xms, 'literal log message (level 1)');

    if ($loglevel == 1) {
        unlike($stderr, qr{ loglevel\ 2 }xms, 'literal log message (level 2) should not be there');
    }
    else {
        like($stderr, qr{ loglevel\ 2 }xms, 'literal log message (level 2)');
        like($stderr, qr{ loglevel\ 4 }xms, 'literal log message (level 4)');
        like($stderr, qr{ loglevel\ 16 }xms, 'literal log message (level 16)');
        unlike($stderr, qr{ loglevel\ 256 }xms, 'literal log message (level 256) should not be there');
    }

    like($stderr, qr{ code:\ 2 }xms, 'result of code execution');

    if ($loglevel == 16) {
        # the invalidity specific tests
        like($stderr, qr{ Invalid\ DEBUG\ statement }xms, 'Invalid debug statement caught');
        like($stderr, qr{ Invalid\ DEBUG\ statement: .* Can't\ find\ string\ terminator }xms, 'Unclosed string caught');
        like($stderr, qr{ Invalid\ DEBUG\ statement: .* Can't\ locate\ class\ method }xms, 'Unknown method caught');
        like($stderr, qr{ Invalid\ DEBUG\ statement: .* Undefined\ subroutine }xms, 'Unknown package caught');
    }
};

subtest 'Partly invalid debug statements, log level 1', $test => 1;
subtest 'Partly invalid debug statements, log level 16', $test => 16;

1;
