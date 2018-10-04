## directly taken from documentation of Test::POD::Coverage

use Test::More 'no_plan';
eval "use Test::Pod::Coverage 1.00";

my @files;

SKIP: {
    skip "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;

    @files = Test::Pod::Coverage::all_modules();
    note "Check the POD coverage in ".scalar @files." files\n";
}

TODO: {
    todo_skip 'We need a lot more code documentation ...';
    foreach my $module (@files) {
            note "Testing POD coverage for $module";
            pod_coverage_ok($module, "$module is covered" );
    }
}
