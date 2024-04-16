## directly taken from documentation of Test::POD::Coverage

use Test::More 'no_plan';
use Module::Load ();

my @files;

eval { Module::Load::autoload('Test::Pod:Coverage') };

SKIP: {
    skip "Test::Pod::Coverage required for testing POD coverage" if $@;

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
