use Test::More tests => 8;
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

ok(mkpath $config{server_dir});

# deployment
ok(system("openxpkiadm deploy $config{server_dir}") == 0);

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
ok(chdir $config{server_dir});

my $args = "--batch --createdirs --";
foreach my $key (keys %configure_settings) {
    $args .= " --setcfgvalue $key=$configure_settings{$key}";
}
diag "Configuring with local options $args";
ok(system("openxpki-configure $args") == 0);

# and back
ok(chdir($dir));

if (! ok(-e $config{config_file})) {
    BAIL_OUT("No server configuration file present ($config{config_file})");
}

diag "Starting OpenXPKI Server.";

$args = "--debug 100" if ($debug);
if (system("openxpkictl --config $config{config_file} $args start") != 0) {
    unlink $config{socket_file};
    BAIL_OUT("Could not start OpenXPKI.");
}

if (! ok(-e $config{socket_file})) {
    unlink $config{socket_file};
    BAIL_OUT("Server did not start (no socket file)");
}

