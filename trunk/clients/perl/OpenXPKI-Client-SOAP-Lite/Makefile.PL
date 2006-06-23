use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client::SOAP::Lite',
    VERSION_FROM        => 'lib/OpenXPKI/Client/SOAP/Lite.pm',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/SOAP/Lite.pm',
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
	'OpenXPKI::Client' => 0,
    },
);
