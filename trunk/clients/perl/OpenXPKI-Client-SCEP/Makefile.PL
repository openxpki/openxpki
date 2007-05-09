use strict;
use warnings;
use English;
use ExtUtils::MakeMaker;

my $vergen = '../../../../tools/vergen';
my $version;

if ( -e($vergen) ) {
    $version = `$vergen --format version`;                                                                                                                 

    if ($CHILD_ERROR == 0) {
        print "Version $version\n";
        open my $fh, '>', 'VERSION' || die 'Could not write VERSION file. Stopped';                                                                         
        print $fh $version;
        close $fh;
    }
}

$version = do {
    local $INPUT_RECORD_SEPARATOR;
    open my $fh, '<', 'VERSION' or die "Could not read VERSION file. Stopped";
    <$fh>;
};

if (! defined $version) {
    die "Cannot read version from file. Stopped";
}

WriteMakefile(
    NAME                => 'OpenXPKI::Client::SCEP',
    VERSION             => $version,
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/SCEP.pm',
    PREREQ_PM => {
        'Test::More'   => 0,
        'NetAddr::IP'  => 0,
        'version'      => 0,
	'OpenXPKI::Client' => 0,
    },
);
