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

# check if infrastructure commands are installed
if (system("openxpkiadm >/dev/null 2>&1") != 0) {
    BAIL_OUT("OpenXPKI deployment environment is not installed");
}

if (-d $config{server_dir}) {
    rmtree($config{server_dir});
}

ok(mkdir $config{server_dir});

exit

# deployment
ok(system("tar -C $config{deployment_dir} -c -f - . | tar -C $config{tmp_dir} -x -f -") == 0);

if (! -x "$config{tmp_dir}/configure") {
    rmtree($config{target_dir});
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

if (system("openxpkictl --configfile start") != 0) {
    rmtree($config{target_dir}) unless $debug;
    BAIL_OUT("Could not start OpenXPKI.");
}

diag "Server started.";

sleep(3);
ok(-e $config{socket_file});

diag "Done.";
