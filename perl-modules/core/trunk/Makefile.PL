use ExtUtils::MakeMaker;

## first we have to find a working OpenSSL 0.9.7 at minimum
## a working 0.9.8 would be better

# OPENSSL_LIB
# OPENSSL_INC
# OPENSSL_PREFIX set
# /usr/local/ssl
# /usr/local
# /usr
# /

my $inc = "";
my $lib = "";

my @paths = ("/usr/local/ssl", "/usr/local", "/usr", "");

push @paths, $ENV{OPENSSL_PREFIX}
    if (exists $ENV{OPENSSL_PREFIX} and length $ENV{OPENSSL_PREFIX});

$inc = $ENV{$OPENSSL_INC}
    if (exists $ENV{$OPENSSL_INC} and length $ENV{$OPENSSL_INC});
$lib = $ENV{$OPENSSL_LIB}
    if (exists $ENV{$OPENSSL_LIB} and length $ENV{$OPENSSL_LIB});

foreach my $path (@paths)
{
    $inc = $path."/include"
        if (not $inc and -d $path."/include");
    $lib = $path."/lib"
        if (not $lib and -d $path."/lib");
}

print STDOUT "OpenSSL library: $lib\n";
print STDOUT "OpenSSL headers: $inc\n";

my $version = `grep '#define OPENSSL_VERSION_TEXT' $inc/openssl/opensslv.h`;
$version =~ s/^.*fips.*$//m;
$version =~ s/\n//g;
$version =~ s/^[^"]*"([^"]*)".*$/$1/;
print STDOUT "OpenSSL version: $version\n";

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'     => 'OpenXPKI',
    'VERSION_FROM'  => 'OpenXPKI.pm',
    'LIBS'     => ["-L$lib -lcrypto"],
    'INC'      => "-I. -I$inc",
    test       => {TESTS => 't/*.t t/*/*.t'},
);
