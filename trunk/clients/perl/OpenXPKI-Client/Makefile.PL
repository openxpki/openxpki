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
    NAME                => 'OpenXPKI::Client',
    VERSION             => $version,
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
    PL_FILES => {},
);
