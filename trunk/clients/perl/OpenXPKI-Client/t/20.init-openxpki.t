use Test::More tests => 7;
use File::Path;
use File::Spec;
use English;

use strict;
use warnings;


our %config;
require 't/common.pl';

my $debug = $config{debug};

diag("Locally deploying OpenXPKI");

ok(-d $config{deployment_dir});
ok(-x "$config{deployment_dir}/configure");

if (-d $config{target_dir}) {
    rmtree($config{target_dir});
}

ok(mkdir $config{target_dir});
ok(mkdir $config{tmp_dir});
ok(mkdir $config{server_dir});

# deployment
ok(system("tar -C $config{deployment_dir} -c -f - . | tar -C $config{tmp_dir} -x -f -") == 0);

if (! -x "$config{tmp_dir}/configure") {
    rmtree($config{target_dir});
    BAIL_OUT("Could not find configure script in $config{tmp_dir}");
}

my ($pw_name) = getpwuid($EUID);
my ($gr_name) = getgrgid($EUID);

my %configure_settings = (
    'dir.prefix' => File::Spec->rel2abs($config{server_dir}),
    'server.socketfile' => File::Spec->rel2abs($config{socket_file}),
    'server.runuser' => $pw_name,
    'server.rungroup' => $pw_name,
    );

my $args = "--batch --";
foreach my $key (keys %configure_settings) {
    $args .= " --setcfgvalue $key=$configure_settings{$key}";
}
diag "Configuring with local options $args";

if (system("cd $config{tmp_dir} && ./configure $args") != 0) {
    rmtree($config{target_dir}) unless $debug;
    BAIL_OUT("Could not configure local OpenXPKI installation.");
}

diag "Installing OpenXPKI Server to $config{server_dir}.";
if (system("cd $config{tmp_dir} && make install") != 0) {
    rmtree($config{target_dir}) unless $debug;
    BAIL_OUT("Could not install OpenXPKI.");
}

diag "Creating OpenXPKI XML configuration in $config{server_dir}/etc.";
if (system("$config{server_dir}/bin/openxpki-configure --batch") != 0) {
    rmtree($config{target_dir}) unless $debug;
    BAIL_OUT("Could not create OpenXPKI XML configuration.");
}

diag "Starting OpenXPKI Server.";

if (system("$config{server_dir}/bin/openxpkictl start") != 0) {
    rmtree($config{target_dir}) unless $debug;
    BAIL_OUT("Could not start OpenXPKI.");
}

diag "Server started.";

sleep(3);
ok(-e $config{socket_file});

diag "Done.";
