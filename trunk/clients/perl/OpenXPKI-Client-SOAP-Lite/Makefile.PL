use strict;
use warnings;
use English;
use ExtUtils::MakeMaker;

my $openxpki_major_version = "0.9";

my $openxpki_revision;

# check if we are using a SVN checkout
if (open my $fh, "svn info 2>/dev/null |") {
  SVN_INFO:
    while (my $line = <$fh>) {
	chomp $line;
	if ($line =~ m{ \A Revision: \s* (\d+) }xms) {
	    $openxpki_revision = $1;
	    last SVN_INFO;
	}
    }
    close $fh;
}

if (defined $openxpki_revision) {
    open my $fh, '>', 'VERSION' || die 'Could not write VERSION file. Stopped';
    print $fh $openxpki_major_version . '.' . $openxpki_revision;
    close $fh;
}

my $version = do {
    local $INPUT_RECORD_SEPARATOR;
    open my $fh, '<', 'VERSION' or return;
    <$fh>;
};

if (! defined $version) {
    die "Cannot read revision from file. Stopped";
}

WriteMakefile(
    NAME                => 'OpenXPKI::Client::SOAP::Lite',
    VERSION             => $version,
    ABSTRACT_FROM       => 'lib/OpenXPKI/Client/SOAP/Lite.pm',
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
	'OpenXPKI::Client' => 0,
    },
);
