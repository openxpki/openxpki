## directly taken from documentation of Test::POD

use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
my @files = all_pod_files();
diag "Check the POD syntax in ".scalar @files." files\n";
all_pod_files_ok();
