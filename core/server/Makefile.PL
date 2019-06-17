use strict;
use warnings;
use English;
use ExtUtils::MakeMaker;

use File::Spec;

my $vergen = '../../tools/vergen';

###########################################################################
# determine OpenSSL version
## first we have to find a working OpenSSL

# OPENSSL_LIB
# OPENSSL_INC
# OPENSSL_PREFIX set
# /usr/local/ssl
# /usr/local
# /usr
# /
# ...

my $openssl_inc_dir = '';
my $openssl_lib_dir = '';
my $openssl_binary  = '';

my @paths = qw( /usr/local/ssl
                /opt/local/ssl
                /usr/local
                /opt/local
                /usr
                /opt
              );

if (exists $ENV{OPENSSL_PREFIX} 
    && $ENV{OPENSSL_PREFIX} ne '') {
    unshift @paths, $ENV{OPENSSL_PREFIX};
}


my $tmp_ver;

PATH:
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
	last PATH;
    }
}

# accept settings from OPENSSL_INC and OPENSSL_LIB if BOTH exist
if (exists $ENV{OPENSSL_INC}    && $ENV{OPENSSL_INC} != "" 
    && exists $ENV{OPENSSL_LIB} && $ENV{OPENSSL_LIB} != "") {

    $openssl_inc_dir = $ENV{OPENSSL_INC};
    $openssl_lib_dir = $ENV{OPENSSL_LIB};
}

die "Could not find usable OpenSSL installation. Stopped" 
    unless defined $openssl_inc_dir;

die "Could not find usable OpenSSL binary. Stopped" 
    unless defined $openssl_binary;

print STDERR "OpenSSL library: $openssl_lib_dir\n";
print STDERR "OpenSSL headers: $openssl_inc_dir\n";
print STDERR "OpenSSL binary:  $openssl_binary\n";

# ask the binary for it's version
# openssl version should produce output like this:
# OpenSSL 0.9.7l 28 Sep 2006
# OpenSSL 1.0.0a 1 Jun 2010
my $openssl_version_string = `$openssl_binary version`;
my ($openssl_version_major, $openssl_version_minor, $openssl_version_fix, $openssl_version_patch, $openssl_version_flavour);
if ($openssl_version_string =~ m/\s*OpenSSL\s+(\d+)\.(\d+)\.(\d+)([a-zA-Z]+)/i) {
    # OpenSSL 0.9
    $openssl_version_flavour = 'OpenSSL';
    $openssl_version_major = $1;
    $openssl_version_minor = $2;
    $openssl_version_fix   = $3;
    $openssl_version_patch = $4;
    print "$openssl_version_flavour version: major=$openssl_version_major, minor=$openssl_version_minor, fix=$openssl_version_fix, patch=$openssl_version_patch\n";
    
} elsif ($openssl_version_string =~ m/\s*(OpenSSL|LibreSSL)\s+(\d+)\.(\d+)\.(\d+)\s+/) {
    # OpenSSL 1.0
    $openssl_version_flavour = $1;
    $openssl_version_major = $2;
    $openssl_version_minor = $3;
    $openssl_version_fix   = $4;
    print "OpenSSL version: major=$openssl_version_major, minor=$openssl_version_minor, fix=$openssl_version_fix\n";
} else {
    print "Problem: malformed openssl version string!\n";
    print STDERR "Consider setting OPENSSL_PREFIX correctly.\n\n";
    exit 1;
}

# Warn on old openssl - should work but lacks support for some features 
if ($openssl_version_major == 0 &&
    $openssl_version_minor == 9 &&
    $openssl_version_fix   == 8) {

    print STDERR "Warning: openssl 0.9.8 found - this will work but lacks some features, e.g. server side key generation!";
              
} elsif ( $openssl_version_flavour =~ m/LibreSSL/i ) {
    
    print STDERR "Warning: LibreSSL found, support for LibreSSL is experimental!";
    
} elsif (not 
    ($openssl_version_flavour =~ m/OpenSSL/i &&
     $openssl_version_major == 1 &&
     (($openssl_version_minor == 0) || ($openssl_version_minor == 1) ))) {
         
    print STDERR "\n";
    print STDERR "ERROR: OpenSSL 0.9.8, 1.0 or 1.1 is required.\n";
    print STDERR "Consider setting OPENSSL_PREFIX correctly.\n\n";
    exit 1;
}

# make OpenSSL binary location available to tests
open my $fh, ">", File::Spec->catfile("t", "cfg.binary.openssl");
print $fh $openssl_binary;
close $fh;


###########################################################################
# determine OpenXPKI version

my $openxpki_version;
if ( -s '../../VERSION' ) {
    # this block is optimized for programmer efficiency
    $openxpki_version = `cat ../../VERSION`;
    chomp $openxpki_version;
} elsif ( -e($vergen) ) {
    # Allow for travis to set PERL in order to use perlbrew perl from PATH
    if ( $ENV{PERL} ) {
        $openxpki_version = `$ENV{PERL} $vergen --format version`;
    } else {
        $openxpki_version = `$vergen --format version`;
    }

    if ($CHILD_ERROR != 0) {
        $openxpki_version = undef;
    }
}

if (! defined $openxpki_version) {
    # make sure we really require OUR LOCAL version file (not some possibly
    # already installed but outdated version file)
    # this is mainly used in archives created from 'make dist' steps
    eval {
 	local @INC = ( '.' );
 	require OpenXPKI::VERSION;
 	$openxpki_version = $OpenXPKI::VERSION::VERSION;
 	print STDERR "OpenXPKI distribution\n";
 	print STDERR "Version from OpenXPKI::Version: $openxpki_version\n";
     };
}

if (! defined $openxpki_version) {
    die "Could not determine OpenXPKI version. Stopped";
}

my $module = "\
# never commit this file to a version control system
package OpenXPKI::VERSION;
our \$VERSION = '$openxpki_version';
1;
__END__

=head1 Name

OpenXPKI::VERSION - version number of OpenXPKI core modules.

=head1 Description

This file is only used to get a clean version number for the
installed OpenXPKI core software. This is required by the XS
library.

=head1 Version

$openxpki_version";

open $fh, ">", File::Spec->catfile('OpenXPKI', 'VERSION.pm') 
    or die "Cannot open version module file OpenXPKI/VERSION.pm!\n";
print $fh $module;
close $fh;


## restore all formerly ignored modules
my $list = `find . -name "*.pm.ignore" -print`;
my @list = split /[\n\s+]/, $list;
foreach my $module (@list)
{
    next if (not defined $module or not length $module);
    $module =~ s/\.ignore$//;
    print STDERR "Restoring module $module ... ";
    if (not rename $module.".ignore", $module)
    {
        print STDERR "FAILED\n";
        print STDERR "Cannot restore formerly ignored module!\n";
        print STDERR "Aborting to ensrue the consistency of the OpenXPKI release.\n";
        exit 1;
    }
    print STDERR "OK\n";
}

## should we ignore some modules?

if (exists $ENV{IGNORE_MODULES})
{
    my $line = $ENV{IGNORE_MODULES};
       $line =~ s/\s+/ /g;
    my @modules = split / /, $line;
    foreach my $module (@modules)
    {
        print STDERR "Module $module is not going to be installed.\n";
        $module =~ s/::/\//g;
        $module .= ".pm" if (substr ($module, length($module)-4,3) ne ".pm");
        if (not rename $module, $module.".ignore")
        {
            print STDERR "Cannot deactivate the module $module!\n";
            print STDERR "Aborting makefile generation to enforce your installation policy.\n";
            exit 1;
        }
    }
}
else
{
    print STDERR "All modules will be installed.\n";
}

## some information about the used OpenXPKI version

print STDERR "This is OpenXPKI version $openxpki_version\n";

# removed code statistics code, it introduces an annoying delay during
# Makefile creation. it was not working accurateley anyway.
# if you wish to generate meaningful statistics use e. g. sloccount instead
#print STDERR "Statistics:\n";
#my $cmd = 'cat OpenXPKI.pm OpenXPKI.xs `find OpenXPKI -type f | grep -r -v "/\."`| wc -l';
#print STDERR "    LOC: ".`$cmd`;
#$cmd = 'cat `find t -type f | grep -r -v "/\."`| wc -l';
#print STDERR "    LOT: ".`$cmd`;
#$cmd = 'cat `find . -type f | grep -r -v "/\."`| wc -l';
#print STDERR "    LOA: ".`$cmd`;

## hack to avoid warnings from Log4perl

eval 'use Log::Log4perl::Logger';
if ($@ eq '') {
  eval '$Log::Log4perl::Logger::NON_INIT_WARNED = 1;';
}
else {
  print STDERR "Logger is not installed. Continue anyway.\n";
}

# check if we should add -shared
# not all platforms support this feature
my %flags = ();

open $fh, '>test.c' or die "Cannot open test.c. Stopped";
print $fh "int main() {}\n";
close $fh;
use Config;
my $cc = $Config{'cc'};

my $cc_supports_shared = 1;
if (open $fh, "$cc -shared -o test test.c 2>&1 |") {
    while (my $line = <$fh>) {
        if ($line =~ m{ unrecognized .* option .* -shared }xms) {
	    $cc_supports_shared = 0;
        }
    }
    close $fh;
    if ($CHILD_ERROR) {
        $cc_supports_shared = 0;
    }

    if (! $cc_supports_shared)
    {
        print STDERR "C compiler does not support -shared.\n";
    }
    else {
        if ($^O ne 'darwin') {
            print STDERR "C compiler supports -share. Adding it to LDDLFLAGS.\n";
            $flags{'LDDLFLAGS'} = '-shared';
        }
        else {
            print STDERR "C compiler claims to support -share. But we are on Mac OS X, experience shows that it still does not work with -share, so we won't add it to LDDLFLAGS ...\n";
        }
    }
}
else {
    print STDERR "Could not run C compiler. Continue anyway.\n";
}

unlink('test.c');
unlink('test');

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'OpenXPKI',
    'VERSION'   => $openxpki_version,
    'LIBS'      => ["-L$openssl_lib_dir -lcrypto"],
    'INC'       => "-I. -I$openssl_inc_dir",
    'CCFLAGS'   => '-O2 -g '.$Config{ccflags},
    'PREREQ_PM' => {
        'Archive::Zip'                  => 0,
        'CGI::Fast'                     => '2.10',
        'CGI::Session'                  => '3.95',
        'CGI'                           => '4.21',
        'Class::Std'                    => '0.0.8',
        'Config::Merge'                 => '1',
        'Config::Std'                   => 0,
        'Config::Versioned'             => 0,
        'Connector'                     => '1.08',
        'Crypt::CBC'                    => '2.29',
        'Crypt::OpenSSL::AES'           => '0.02',      # for e.g. OpenXPKI::Crypto::VolatileVault
        'CryptX' =>             => '0.1.2',        
        'Crypt::Cipher::AES'               => 0,           # replacement to support keysize > 128
        'Crypt::PKCS10'                 => '2.000',
        'Crypt::X509'                   => 0,
        'Crypt::X509::CRL'              => 0,
        'Data::Password'                => '1.07',
        'Data::Serializer'              => '0.44',
        'Data::UUID'                    => 0,           # for OpenXPKI::Template::Plugin::Utils and CPAN
        'Date::Parse'                   => '0',
        'DateTime::Format::DateParse'   => '0.04',
        'DateTime::Format::Strptime'    => 0,           # for OpenXPKI::Server::Workflow::Persister::DBI
        'DateTime'                      => '0.22',
        'DBD::Mock'                     => '1.45',
        'DBD::SQLite'                   => '1.52',      # for tests of OpenXPKI::Server::Database
        'DBI'                           => '1',
        'DBIx::Handler'                 => '0.14',      # for OpenXPKI::Server::Database
        'Devel::NYTProf'                => 0,           # for CPAN
        'English'                       => '1',         # for broken Perl installations like on Ubuntu Drapper
        'Exception::Class'              => '1.22',
        'HTML::Entities'                => 0,
        'IO::Prompt'                    => '0.099004',  # for deployment tools
        'JSON'                          => 0,
        'Locale::gettext_pp'            => 0,
        'Log::Log4perl'                 => '0.51',
        'Log::Log4perl::Layout::JSON'   => 0,
        'LWP::UserAgent'                => '6.05',      # Constituent of module  libwww-perl
        'Math::BigInt'                  => '1.9993',    # makes FreeBSD happy
        'MIME::Entity'                  => 0,
        'Module::Load'                  => '0.32',      # for OpenXPKI::Server::Database
        'Moose'                         => '1',
        'MooseX::Params::Validate'      => '0.21',      # for OpenXPKI::Server::Database
        'Net::DNS'                      => '0.83',
        'Net::LDAP'                     => '0.32',
        'Net::Server'                   => '0.94',
        'NetAddr::IP'                   => 0,
        'Params::Validate'              => '0.77',
        'Proc::Daemon'                  => '0.23',
        'Proc::ProcessTable'            => '0.43',
        'Proc::SafeExec'                => '1.4',
        'Regexp::Common'                => '2',
        ## 'RT::Client::REST::Ticket'      => '0', CURRENTLY OPTIONAL
        ## 'RT::Client::REST'              => '0', CURRENTLY OPTIONAL
        'SOAP::Lite'                    => 0,
        'SQL::Abstract::More'           => '1.28',      # for OpenXPKI::Server::Database
        'Sub::Exporter'                 => 0,           # for OpenXPKI::MooseParams
        'Sys::SigAction'                => '0.06',
        'Template'                      => '2.15',
        'Test::More'                    => '1.001008',
        'Test::Pod::Coverage'           => '1.00',
        'Test::Pod'                     => '1.00',
        'Text::CSV_XS'                  => '0.23',
        'Time::HiRes'                   => '1',
        'Try::Tiny'                     => '0.28',
        'Workflow'                      => '0.27',
        'XML::Simple'                   => '1',
        'YAML::Tiny'                    => '1.69',
    },
    test       => {TESTS => 't/*/*.t',
                  },
    macro      => { OPENSSL_BINARY => $openssl_binary,
                  },
    clean      => {FILES => [ 't/50_auth/cgisess_*',
                              't/*/*.db', 't/30_dbi/sqlite.db._*',
                              'OpenXPKI/VERSION.pm',
                              't/25_crypto/ca1', 't/25_crypto/ca2',
                              't/25_crypto/token_test.xml', 't/50_auth/auth_test.xml', 't/config_test.xml',
                              't/28_log/openxpki.log',
                              't/cfg.binary.openssl']},
    'XSPROTOARG' => '-noprototypes',
    'EXE_FILES' => [ 'bin/openxpkictl','bin/openxpkicmd', 'bin/openxpkiadm', 'bin/openxpkicli'],    
    %flags,
);
