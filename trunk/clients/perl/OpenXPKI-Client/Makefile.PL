use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OpenXPKI::Client',
    VERSION_FROM        => 'lib/OpenXPKI/Client.pm',
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client.pm',
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
);
