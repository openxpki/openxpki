use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Bundle::OpenXPKI',
    AUTHOR              => 'Alexander Klink <alech@cpan.org>',
    VERSION_FROM        => 'lib/Bundle/OpenXPKI.pm',
    ABSTRACT_FROM       => 'lib/Bundle/OpenXPKI.pm',
    PL_FILES            => {},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Bundle-OpenXPKI-*' },
);
