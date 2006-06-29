use strict;
use warnings;
use ExtUtils::MakeMaker;

if (-e ".svn")
{
    my $result = `svn info`;
       $result =~ s/.*\nRevision:\s*([0-9]+).*/$1/s;
       open FD, ">VERSION" and print FD "0.9.$result" and close FD or
           die "Cannot write revision file.\n";
}

my $version = undef;
open FD, "VERSION" and $version = <FD> and close FD
    or die "Cannot read revision from file.\n";

WriteMakefile(
    NAME                => 'OpenXPKI::Client::HTML::Mason',
    AUTHOR              => 'Martin Bartosch <m.bartosch@cynops.de>',
    VERSION             => $version,
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/HTML/Mason.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'       => 0,
        'version'          => 0,
        'OpenXPKI::Client' => 0,
        'OpenXPKI::i18n'   => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-HTML-Mason-*' },
);
