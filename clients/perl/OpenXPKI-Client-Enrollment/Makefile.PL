use strict;
use warnings;
use English;
use ExtUtils::MakeMaker;

my $vergen = '../../../tools/vergen';
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
    NAME                => 'OpenXPKI::Client::Enrollment',
    AUTHOR              => 'Scott Hardin <scott@hnsc.de>',
    VERSION             => $version,
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/Enrollment.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'       => 0,
        'version'          => 0,
        'Mojolicious'       => 0,
        'Proc::SafeExec'    => 0,
        'Config::Std'       => 0, # only needed for current build scripts
        'Moose'             => 0, # only needed for test, but include anyway
        'Template'          => '2.25', # convenient for config/deploy scripts
    },
    test => {TESTS => 't/*/*.t t/*.t'},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-Enrollment-*' },
);
