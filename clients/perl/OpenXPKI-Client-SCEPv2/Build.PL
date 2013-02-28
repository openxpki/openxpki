use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'OpenXPKI::Client::SCEPv2',
    license             => 'perl',
    dist_author         => 'OpenXPKI Foundation <debian@openxpki.org>',
    dist_version_from   => 'lib/OpenXPKI/Client/SCEPv2.pm',
    requires => {        
        'version'    => 0,
    },
    add_to_cleanup      => [ 'OpenXPKI-Client-SCEPv2-*' ],
);

$builder->create_build_script();
