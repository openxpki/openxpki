use strict;
use warnings;

# Core modules
use Test::More;
use English;
use FindBin qw( $Bin );

plan tests => 5;

use_ok('OpenXPKI::Debug');

my $test = sub {
    my ($module, $loglevel) = @_;
    # map desired loglevel to a bitmask
    my $bitmask = { 1 => 0b01, 2 => 0b11, }->{$loglevel};

    plan tests => 6 + ($loglevel == 1 ? 2 : 4);

    my $stderr = `$^X -I$Bin $Bin/main.pl $module.pm $bitmask 2>&1`;
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

    like($stderr, qr/ ${module}::START /xms, 'module name and method');
    like($stderr, qr{ loglevel\ 1 }xms, 'literal log message (level 1)');

    if ($loglevel == 1) {
        unlike($stderr, qr{ loglevel\ 2 }xms, 'literal log message (level 2) should not be there');
    }
    else {
        like($stderr, qr{ loglevel\ 2 }xms, 'literal log message (level 2)');
        unlike($stderr, qr{ loglevel\ 4 }xms, 'literal log message (level 4) should not be there');
    }

    like($stderr, qr{ code:\ 2 }xms, 'result of code execution');
};

subtest 'Standard debug output, log level 1', $test => ("TestModule", 1);
subtest 'Standard debug output, log level 2', $test => ("TestModule", 2);

subtest 'Standard debug output, no explicit package spec, log level 1', $test => ("TestModuleUseWithout", 1);
subtest 'Standard debug output, no explicit package spec, log level 2', $test => ("TestModuleUseWithout", 2);

1;
