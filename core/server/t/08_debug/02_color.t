use strict;
use warnings;

# Core modules
use Test::More;
use English;
use FindBin qw( $Bin );

plan tests => 3;

eval {
    use Term::ANSIColor;
};
if ($EVAL_ERROR) {
    plan skip_all => 'Term::ANSIColor not installed';
}

use_ok('OpenXPKI::Debug');

my $test = sub {
    my ($loglevel) = @_;
    # map desired loglevel to a bitmask
    my $bitmask = { 1 => 0b01, 2 => 0b11, }->{$loglevel};

    plan tests => 6 + ($loglevel == 1 ? 2 : 6);

    my $stderr = `$^X -I$Bin $Bin/main.pl TestModuleColor.pm $bitmask 2>&1`;

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
        unlike($stderr, qr{ DEBUG:4 }xms, '"DEBUG:4" string should not be there');
    }

    like($stderr, qr{ TestModuleColor::START }xms, 'module name and method');
    like($stderr, qr{ loglevel\ 1 }xms, 'literal log message (level 1)');

    if ($loglevel == 1) {
        unlike($stderr, qr{ loglevel\ 2 }xms, 'literal log message (level 2) should not be there');
    }
    else {
        like($stderr, qr{ loglevel\ 2 }xms, 'literal log message (level 2)');
        unlike($stderr, qr{ loglevel\ 4 }xms, 'literal log message (level 4) should not be there');
    }

    like($stderr, qr{ code:\ 2 }xms, 'result of code execution');

    if ($loglevel == 2) {
        # the color specific tests
        my $red_start = chr(0x1b) . '\[31m';
        my $color_stop  = chr(0x1b) . '\[0m';

        like($stderr, qr{ $red_start }xms, 'Output contains ANSI red start code');
        like($stderr, qr{ $color_stop }xms, 'Output contains ANSI stop coloring code');
    }
};

subtest 'Colored debug output, log level 1', $test => 1;
subtest 'Colored debug output, log level 2', $test => 2;

1;
