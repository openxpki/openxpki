use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'OpenXPKI::Client',
    license             => 'perl',
    dist_author         => 'Martin Bartosch <m.bartosch@cynops.de>',
    dist_version_from   => 'lib/OpenXPKI/Client.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'OpenXPKI-Client-*' ],
);

$builder->create_build_script();
