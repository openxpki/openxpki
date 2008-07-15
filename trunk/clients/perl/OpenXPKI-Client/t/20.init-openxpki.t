use Test::More tests => 9;
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

my $instancedir = $config{server_dir};

if (length($instancedir) < 10) {
    BAIL_OUT("Instance directory $instancedir not acceptable.");
}

if (-d $instancedir) {
    rmtree($instancedir);
}

ok(mkpath $instancedir);

# deployment
ok(system("openxpkiadm deploy --prefix $instancedir") == 0);

# meta config should now exist
ok(-e "$config{config_dir}/openxpki.conf");

my ($pw_name) = getpwuid($EUID);
my ($gr_name) = getgrgid($EUID);
my %configure_settings = (
    'dir.prefix' => File::Spec->rel2abs($instancedir),
    'server.socketfile' => File::Spec->rel2abs($config{socket_file}),
    'server.runuser' => $pw_name,
    'server.rungroup' => $gr_name,
    'database.type' => 'SQLite',
    'database.name' => "$instancedir/sqlite.db",
);

# configure in this directory
my $dir = getcwd;
ok(chdir $instancedir);

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

ok(system("openxpkiadm initdb --config $config{config_file}") == 0);

diag "Starting OpenXPKI Server.";

#$args = "";
# redirect to /dev/null, see OpenXPKI::Tests for the reason (prove hangs)
$args = ">/dev/null 2>/dev/null";
$args = "--debug 100 --debug OpenXPKI::XML::Config:0 --debug OpenXPKI::XML::Cache:0 >/dev/null 2>/dev/null" if ($debug);
if (system("openxpkictl --config $config{config_file} $args start") != 0) {
    unlink $config{socket_file};
    BAIL_OUT("Could not start OpenXPKI.");
}

if (! ok(-e $config{socket_file})) {
    unlink $config{socket_file};
    BAIL_OUT("Server did not start (no socket file)");
}

