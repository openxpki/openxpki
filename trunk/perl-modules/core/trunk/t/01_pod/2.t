## directly taken from documentation of Test::POD::Coverage

use Test::More;
eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;
my @files = Test::Pod::Coverage::all_modules();
print STDERR "Check the POD coverage in ".scalar @files." files\n";
all_pod_coverage_ok();
