use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client::SCEP',
    AUTHOR              => 'Martin Bartosch <m.bartosch@cynops.de>',
    VERSION_FROM        => 'lib/OpenXPKI/Client/SCEP.pm',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/SCEP.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-SCEP-*' },
);
