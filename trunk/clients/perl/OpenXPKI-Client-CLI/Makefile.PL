use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client::CLI',
#    VERSION_FROM        => 'lib/OpenXPKI/Client/CLI.pm',
    VERSION             => '0.0.1',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/CLI.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
	'OpenXPKI::Client' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-CLI-*' },
);
