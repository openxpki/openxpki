use strict;
use warnings;

# Core modules
use File::Path qw( make_path );
use File::Temp qw( tempdir );
use English;
use TAP::Parser::YAMLish::Writer;

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;
use Log::Log4perl qw(:easy);

plan tests => 6;

my $config_dir = tempdir( CLEANUP => 1 );
make_path("$config_dir/system") or die "Could not create configuration subdir";
my $config_file = "$config_dir/system/test.yaml";


use_ok "OpenXPKI";
use_ok "OpenXPKI::Config";

#
# Setup
#
Log::Log4perl->easy_init($ERROR);

my $cfg_data = {
    name => "main",
    env => {
        castle => "Neuschwanstein",
        forest => "Schwarzwald",
    },
    service => {
        one => {
            id => 5,
        },
    },
};
my $lines = [];
TAP::Parser::YAMLish::Writer->new->write($cfg_data, $lines);
pop @$lines; shift @$lines; # remove --- and ... from beginning/end
OpenXPKI->write_file(FILENAME => $config_file, CONTENT => join("\n", @$lines) );

#
# Tests
#
my $config;
lives_ok {
    $config = OpenXPKI::Config->new(config_dir => $config_dir);
} "OpenXPKI::Config->new";

lives_and {
    is $config->get('system.test.name'), $cfg_data->{name}
} "get - query scalar value";

lives_and {
    is $config->get('system.test.service.one.id'), $cfg_data->{service}->{one}->{id}
} "get - scalar value in hierarchy";

lives_and {
    cmp_deeply $config->get_hash('system.test.env'), $cfg_data->{env}
} "get_hash - query hash";

1;
