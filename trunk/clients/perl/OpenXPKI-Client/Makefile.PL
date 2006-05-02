use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client',
#    VERSION_FROM        => 'lib/OpenXPKI/Client.pm',
    VERSION             => '0.0.1',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Class::Std' => 0,
        'OpenXPKI::Debug' => 0,
        'OpenXPKI::Exception' => 0,
        'OpenXPKI::Transport::Simple' => 0,
        'OpenXPKI::Serialization::Simple' => 0,
        'OpenXPKI::Serialization::JSON' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-*' },
);
