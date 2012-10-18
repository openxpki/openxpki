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
        'HTML::Mason'      => 1,
        'HTTP::Server::Simple::Mason' => 0,
        'Test::HTTP::Server::Simple'  => 0,
        'WWW::Mechanize'   => 0,
        'Data::Dumper'     => 0,
        'CGI::Cookie'      => 0,
        'URI::Escape'      => 0,
        'HTML::Entities'   => 0,
        'Data::SpreadPagination' => 0,
        'File::Spec'       => 0,
        'OpenXPKI::DateTime'  => 0,
        'OpenXPKI::Exception' => 0,
        'OpenXPKI::Serialization::Simple' => 0,
        'OpenXPKI::DN'     => 0,
        'Encode'           => 0,
        'Class::Std'       => 0,
        'List::Util'       => 0,
        'XML::Simple'      => 0,
        'XML::Parser'      => 0,
        'Digest::SHA1'     => 0,
    },
    test => {TESTS => 't/*/*.t t/*.t'},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'OpenXPKI-Client-HTML-Mason-*' },
);
