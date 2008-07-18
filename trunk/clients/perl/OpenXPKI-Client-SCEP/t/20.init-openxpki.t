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
my $stderr = '2>/dev/null';
#if ($debug) {
#    $stderr = '';
#}

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
diag("Deploying ...");
ok(system("openxpkiadm deploy --prefix $instancedir $stderr") == 0);
# meta config should now exist
ok(-e "$config{config_dir}/openxpki.conf");

my ($pw_name) = getpwuid($EUID);
my ($gr_name) = getgrgid($EUID);
my %configure_settings = (
    'dir.prefix' => File::Spec->rel2abs($instancedir),
    'dir.dest' => File::Spec->rel2abs($instancedir),
    'server.socketfile' => File::Spec->rel2abs($config{socket_file}),
    'server.runuser' => $pw_name,
    'server.rungroup' => $gr_name,
    'database.type'   => 'SQLite',
    'database.name'   => "$instancedir/var/openxpki/sqlite.db",
    );

# configure in this directory
my $dir = getcwd;
ok(chdir $instancedir);

my $args = "--batch --createdirs --";
foreach my $key (keys %configure_settings) {
    $args .= " --setcfgvalue $key=$configure_settings{$key}";
}
diag("Configuring ...");
ok(system("openxpki-configure $args $stderr") == 0);


# and back
ok(chdir($dir));

if (! ok(-e $config{config_file})) {
    BAIL_OUT("No server configuration file present ($config{config_file})");
}

diag("Initializing database");
ok(system("openxpkiadm initdb --config $config{config_file} $stderr") == 0);

