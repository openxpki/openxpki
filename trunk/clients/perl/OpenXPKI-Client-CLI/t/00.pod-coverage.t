use Test::More 'no_plan';
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
my @files = Test::Pod::Coverage::all_modules();
diag "Checking the POD coverage in " . scalar @files . " files\n";

TODO: {
    local $TODO = 'We need more POD coverage ...';
    foreach my $module (@files) {
        pod_coverage_ok($module, "$module is covered");
    }
}
