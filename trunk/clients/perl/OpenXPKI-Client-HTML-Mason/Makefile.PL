use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client::HTML::Mason',
    AUTHOR              => 'Martin Bartosch <m.bartosch@cynops.de>',
    VERSION_FROM        => 'lib/OpenXPKI/Client/HTML/Mason.pm',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/HTML/Mason.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-HTML-Mason-*' },
);
