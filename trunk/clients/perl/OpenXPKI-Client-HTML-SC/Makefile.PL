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
        open my $fh, '>', 'VERSION' || die 'Could not write VERSION file. Stoppe
d';
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
    NAME                => 'OpenXPKI::Client::HTML::SC',
    AUTHOR              => q{Arkadius Litwinczuk <arkadius.litwinczuk@db.com>},
    VERSION             => $version,
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/HTML/SC.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
	'Apache2::Controller' => 0,
	'JSON' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-HTML-SC-*' },
);
