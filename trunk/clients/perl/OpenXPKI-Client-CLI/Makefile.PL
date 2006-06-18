use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client::CLI',
    VERSION_FROM        => 'lib/OpenXPKI/Client/CLI.pm',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/CLI.pm',
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
	'OpenXPKI::Client' => 0,
    },
);
