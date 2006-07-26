use strict;
use warnings;
use ExtUtils::MakeMaker;

my $openxpki_major_version = "0.9";

if (-e ".svn")
{
    my $result = `svn info`;
       $result =~ s{ .*\n Last\ Changed\ Rev: \s* (\d+) .* }{$1}xs;
       open FD, ">VERSION" and print FD "$openxpki_major_version.$result" and close FD or
           die "Cannot write revision file.\n";
}

my $version = undef;
open FD, "VERSION" and $version = <FD> and close FD
    or die "Cannot read revision from file.\n";

WriteMakefile(
    NAME                => 'OpenXPKI::Client::SCEP',
    VERSION             => $version,
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/SCEP.pm',
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
	'OpenXPKI::Client' => 0,
    },
);
