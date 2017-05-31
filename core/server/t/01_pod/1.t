use Test::More;
use FindBin qw( $Bin );

eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

my @files = all_pod_files("$Bin/../../");
note "Check the POD syntax in ".scalar @files." files\n";
all_pod_files_ok(@files);
