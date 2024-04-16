use Test::More;
use FindBin qw( $Bin );
use Module::Load ();

eval { Module::Load::autoload('Test::Pod') };
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

my @files = all_pod_files("$Bin/../../");
note "Check the POD syntax in ".scalar @files." files\n";
all_pod_files_ok(@files);
