use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client::SCEP',
    VERSION_FROM        => 'lib/OpenXPKI/Client/SCEP.pm',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/SCEP.pm',
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
	'OpenXPKI::Client' => 0,
    },
);
