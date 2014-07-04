## directly taken from documentation of Test::POD::Coverage

use Test::More 'no_plan';
eval "use Test::Pod::Coverage 1.00";

SKIP: {
    skip "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;

    my @files = Test::Pod::Coverage::all_modules();
    diag "Check the POD coverage in ".scalar @files." files\n" if $ENV{VERBOSE};
}

TODO: {
    todo_skip 'We need a lot more code documentation ...';
    foreach my $module (@files) {
            diag "Testing POD coverage for $module" if $ENV{VERBOSE};
            pod_coverage_ok($module, "$module is covered" );
    }
}
