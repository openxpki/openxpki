use strict;
use warnings;
use ExtUtils::MakeMaker;

use File::Spec;

## first we have to find a working OpenSSL 0.9.8 at minimum

# OPENSSL_LIB
# OPENSSL_INC
# OPENSSL_PREFIX set
# /usr/local/ssl
# /usr/local
# /usr
# /
# ...

my $openssl_inc_dir = "";
my $openssl_lib_dir = "";
my $openssl_binary = "";

my @paths = qw( /usr/local/ssl
                /opt/local/ssl
                /usr/local
                /opt/local
                /usr
                /opt
              );

if (exists $ENV{OPENSSL_PREFIX} && $ENV{OPENSSL_PREFIX} ne "") {
    @paths = ($ENV{OPENSSL_PREFIX}, @paths);
}


my $tmp_ver;

foreach my $path (@paths)
{
    my $tmp_inc = File::Spec->catfile($path, 'include');
    $tmp_ver = File::Spec->catfile($tmp_inc, 'openssl', 'opensslv.h');
    my $tmp_lib = File::Spec->catfile($path, 'lib');
    my $tmp_bin = File::Spec->catfile($path, 'bin', 'openssl');

    if (-d $tmp_inc &&
	-d $tmp_lib &&
	-r $tmp_ver &&
	-r $tmp_bin && -x $tmp_bin) {

	$openssl_inc_dir = $tmp_inc;
	$openssl_lib_dir = $tmp_lib;
	$openssl_binary  = $tmp_bin;
	last;
    }
}

# accept settings from OPENSSL_INC and OPENSSL_LIB if BOTH exist
if (exists $ENV{OPENSSL_INC} && $ENV{OPENSSL_INC} != "" &&
    exists $ENV{OPENSSL_LIB} && $ENV{OPENSSL_LIB} != "") {

    $openssl_inc_dir = $ENV{OPENSSL_INC};
    $openssl_lib_dir     = $ENV{OPENSSL_LIB};
}

die "Could not find usable OpenSSL installation. Stopped" 
    unless defined $openssl_inc_dir;

die "Could not find usable OpenSSL binary. Stopped" 
    unless defined $openssl_binary;

print STDOUT "OpenSSL library: $openssl_lib_dir\n";
print STDOUT "OpenSSL headers: $openssl_inc_dir\n";
print STDOUT "OpenSSL binary:  $openssl_binary\n";

my $version = `grep '#define OPENSSL_VERSION_TEXT' $tmp_ver`;

$version =~ s/^.*fips.*$//m;
$version =~ s/\n//g;
$version =~ s/^[^"]*"([^"]*)".*$/$1/;
print STDOUT "OpenSSL version: $version\n";
$version =~ s/^\s*OpenSSL\s*0\.9\.//i;
$version =~ s/^([0-9]+).*$/$1/;
if ($version < 8)
{
    print STDERR "==============================================\n";
    print STDERR "WARNING: You need at minimum an OpenSSL 0.9.8!\n";
    print STDERR "==============================================\n";
}

# make OpenSSL binary location available to tests
open my $fh, ">", File::Spec->catfile("t", "cfg.binary.openssl");
print $fh $openssl_binary;
close $fh;

#determine version
my $files = `find . -name entries -print`;
if ($files)
{
    $files =~ s/\n/ /g;
    my $commited = `grep -e "revision\\|committed-rev" $files`;
    my $revision = 0;
    foreach my $line (split (/\n/, $commited))
    {
        $line =~ s/^.*:\s+committed-rev="([0-9]+)".*$/$1/;
        $line =~ s/^.*:\s+revision="([0-9]+)".*$/$1/;
        $revision = $line if ($line > $revision);
    }
    print STDOUT "Revision:        $revision\n";
    $version = "0.9.$revision";
    `echo \\# never commit this file to a version control system > VERSION`;
    `echo $version >> VERSION`;
} else {
    $version = `cat VERSION`;
    $version =~ s/#[^\n]*\n//g;
    $version =~ s/\n//g;
}
print STDOUT "Version:         $version\n";

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'OpenXPKI',
    'VERSION'   => $version,
    'LIBS'      => ["-L$openssl_lib_dir -lcrypto"],
    'INC'       => "-I. -I$openssl_inc_dir",
    'PREREQ_PM' => {'CGI::Session'           => '3.95',
                    'DBI'                    => 1,
                    'Date::Parse'            => 1,
                    'DateTime'               => "0.22",
                    'Digest::MD5'            => 1,
                    'Digest::SHA1'           => 1,
                    'Exception::Class'       => "1.22",
                    ## includes the version of libintl-perl which includes Locale::Messages
                    'Locale::TextDomain'     => 1,
                    'Log::Log4perl'          => '0.51',
                    'Math::BigInt'           => 1,
                    'Test'                   => 1,
                    'Test::Pod'              => "1.00",
                    'Test::Pod::Coverage'    => "1.00",
                    'Text::CSV_XS'           => "0.23",
                    'Time::HiRes'            => 1,
                    'Workflow'               => '0.15',
                    'XML::Filter::XInclude'  => 1,
                    'XML::Parser'            => 1,
                    'XML::SAX'               => '0.12',
                    'XML::SAX::Writer'       => '0.44',
                    'XML::Simple'            => 1,
                    'XML::Validator::Schema' => '1.08',
                    'XML::SAX::PurePerl'     => '0.90',
                   },
    test       => {TESTS => 't/*/*.t',
                  },
    macro      => { OPENSSL_BINARY => $openssl_binary,
                  },
);
