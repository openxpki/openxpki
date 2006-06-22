use Test::More tests => 15;
use File::Path;
use File::Spec;
use Cwd;
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
ok(mkdir "$config{server_dir}/etc");
ok(mkdir "$config{server_dir}/var");
ok(mkdir "$config{server_dir}/share");
ok(mkdir "$config{server_dir}/share/locale");
ok(mkdir $config{config_dir});
ok(mkdir $config{var_dir});
ok(mkdir "$config{server_dir}/var/openxpki/session");

# deployment
ok(system("openxpkiadm deploy $config{config_dir}") == 0);

# meta config should now exist
ok(-e "$config{config_dir}/openxpki.conf");

my ($pw_name) = getpwuid($EUID);
my ($gr_name) = getgrgid($EUID);
my %configure_settings = (
    'dir.prefix' => File::Spec->rel2abs($config{server_dir}),
    'server.socketfile' => File::Spec->rel2abs($config{socket_file}),
    'server.runuser' => $pw_name,
    'server.rungroup' => $pw_name,
    );

# configure in this directory
my $dir = getcwd;
ok(chdir $config{config_dir});
my $args = "--batch --";
foreach my $key (keys %configure_settings) {
    $args .= " --setcfgvalue $key=$configure_settings{$key}";
}
diag "Configuring with local options $args";
ok(system("openxpki-configure $args") == 0);
# and back
ok(chdir($dir));

if (!ok(-e $config{config_file})) {
    rmtree($config{server_dir}) unless $debug;
    BAIL_OUT("No server configuration file present ($config{config_file})");
}

diag "Starting OpenXPKI Server.";

if (system("openxpkictl --config $config{config_file} start") != 0) {
    unlink $config{socket_file};
    BAIL_OUT("Could not start OpenXPKI.");
}

diag "Server started.";
sleep(3);
if (! ok(-e $config{socket_file})) {
    unlink $config{socket_file};
    BAIL_OUT("Server did not start (no socket file)");
}

diag "Done.";
