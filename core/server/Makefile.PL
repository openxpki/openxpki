use strict;
use warnings;
use English;
use ExtUtils::MakeMaker;

use File::Spec;

my $vergen = '../../tools/vergen';
my $fh;

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
foreach my $module (@list) {
    next if (not defined $module or not length $module);
    $module =~ s/\.ignore$//;
    print STDERR "Restoring module $module ... ";
    if (not rename $module.".ignore", $module) {
        print STDERR "FAILED\n";
        print STDERR "Cannot restore formerly ignored module!\n";
        print STDERR "Aborting to ensrue the consistency of the OpenXPKI release.\n";
        exit 1;
    }
    print STDERR "OK\n";
}

## should we ignore some modules?
if (exists $ENV{IGNORE_MODULES}) {
    my $line = $ENV{IGNORE_MODULES};
    $line =~ s/\s+/ /g;
    my @modules = split / /, $line;
    foreach my $module (@modules) {
        print STDERR "Module $module is not going to be installed.\n";
        $module =~ s/::/\//g;
        $module .= ".pm" if (substr ($module, length($module)-4,3) ne ".pm");
        if (not rename $module, $module.".ignore") {
            print STDERR "Cannot deactivate the module $module!\n";
            print STDERR "Aborting makefile generation to enforce your installation policy.\n";
            exit 1;
        }
    }
} else {
    print STDERR "All modules will be installed.\n";
}

## some information about the used OpenXPKI version
print STDERR "This is OpenXPKI version $openxpki_version\n";

## hack to avoid warnings from Log4perl
eval {
    require Log::Log4perl::Logger;
    no warnings 'once';
    $Log::Log4perl::Logger::NON_INIT_WARNED = 1;
};
if ($@) {
    print STDERR "Log::Log4perl is not installed. Continuing anyway.\n";
}

# check if we should add -shared
# not all platforms support this feature
my %flags = ();

open $fh, ">", "test.c" or die "Cannot open test.c. Stopped";
print $fh "int main() {}\n";
close $fh;

use Config;
my $cc = $Config{'cc'};

my $cc_supports_shared = 1;
if (open $fh, "-|", "$cc -shared -o test test.c 2>&1") {
    while (my $line = <$fh>) {
        if ($line =~ m{ unrecognized .* option .* -shared }xms) {
            $cc_supports_shared = 0;
        }
    }
    close $fh;
    if ($CHILD_ERROR) {
        $cc_supports_shared = 0;
    }

    if (! $cc_supports_shared) {
        print STDERR "C compiler does not support -shared.\n";
    } else {
        if ($^O ne 'darwin') {
            print STDERR "C compiler supports -share. Adding it to LDDLFLAGS.\n";
            $flags{'LDDLFLAGS'} = '-shared';
        } else {
            print STDERR "C compiler claims to support -share. But we are on Mac OS X, experience shows that it still does not work with -share, so we won't add it to LDDLFLAGS ...\n";
        }
    }
} else {
    print STDERR "Could not run C compiler. Continue anyway.\n";
}

unlink('test.c');
unlink('test');

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'OpenXPKI',
    'VERSION'   => $openxpki_version,
    'LIBS'      => ["-lcrypto"],
    'INC'       => "-I.",
    'CCFLAGS'   => '-O2 -g '.$Config{ccflags},
    'PREREQ_PM' => {
        'Archive::Zip'                  => 0,
        'Authen::SASL'                  => 0, # required for Auth in SMTP
        'CGI::Fast'                     => '2.10',
        'CGI::Session'                  => '3.95',
        'CGI'                           => '4.21',
        'Cache::LRU'                    => 0,
        'Class::Std'                    => '0.0.8',
        'Config::Merge'                 => '1',
        'Config::Std'                   => 0,
        'Connector'                     => '1.43',
        'Crypt::Argon2'                 => 0,
        'Crypt::CBC'                    => '2.29',
        'Crypt::OpenSSL::AES'           => '0.02',      # e.g. OpenXPKI::Crypto::VolatileVault
        'CryptX'                        => '0.068',     # Crypt::* modules for key checking, Ciphers for Crypt::CBC
        'Crypt::JWT'                    => 0,
        'Crypt::PKCS10'                 => '2.005',
        'Crypt::Rijndael'               => '1.13',      # OpenXPKI::Crypto::Secret::SplitEncrypted, via Crypt::CBC
        'Crypt::X509'                   => '0.53',
        'Data::Serializer'              => '0.44',
        'Data::UUID'                    => 0,           # OpenXPKI::Template::Plugin::Utils and CPAN
        'Date::Parse'                   => '0',
        'DateTime::Format::DateParse'   => '0.04',
        'DateTime::Format::Strptime'    => 0,           # OpenXPKI::Server::Workflow::Persister::DBI
        'DateTime'                      => '0.22',
        'DBD::Mock'                     => '1.45',
        'DBD::SQLite'                   => '1.52',      # tests of OpenXPKI::Server::Database
        'DBI'                           => '1',
        'DBIx::Handler'                 => '0.14',      # OpenXPKI::Server::Database
        'Devel::NYTProf'                => 0,           # CPAN
        'English'                       => '1',         # for broken Perl installations like on Ubuntu Drapper
        'Exception::Class'              => '1.22',
        'Feature::Compat::Try'          => '0.05',      # 0.5 is included in Debian Bookworm
        'File::Which'                   => '1.27',      # docker-test.pl
        'HTML::Entities'                => 0,
        'Import::Into'                  => '1.002005',  # OpenXPKI::Debug
        'IO::Pty::Easy'                 => '0.10',      # OpenXPKI::Server::ProcTerminal::Process (EE code)
        'IO::Prompt'                    => '0.099004',  # for deployment tools
        'JSON'                          => 0,
        'JSON::PP'                      => '4.02',      # rpc.fcgi; 4.02000-1 is included in Debian Buster
        'Locale::gettext_pp'            => 0,
        'Log::Log4perl'                 => '0.51',
        'Log::Log4perl::Layout::JSON'   => 0,
        'LWP::UserAgent'                => '6.05',      # Constituent of module libwww-perl
        'Math::BigInt'                  => '1.9993',    # makes FreeBSD happy
        'MIME::Entity'                  => 0,
        'Module::Load'                  => '0.32',      # OpenXPKI::Server::Database
        'Mojolicious'                   => '9.31',      # 9.31 is included in Debian Bookworm
        'Moose'                         => '1',
        'MooseX::ClassAttribute'        => 0,
        'MooseX::InsideOut'             => '0.106',     # OpenXPKI::Crypto::Secret::Split etc.
        'MooseX::NonMoose'              => 0,           # OpenXPKI::Server::Workflow::Validator::PasswordQuality
        'MooseX::Params::Validate'      => '0.21',      # OpenXPKI::Server::Database
        'MooseX::StrictConstructor'     => '0.21',
        'Net::DNS'                      => '0.83',
        'Net::LDAP'                     => '0.32',
        'Net::Server'                   => '0.94',
        'NetAddr::IP'                   => 0,
        'Params::Validate'              => '0.77',
        'Pod::POM'                      => '2.01',
        'PPI'                           => 0,
        'Proc::Daemon'                  => '0.23',
        'Proc::ProcessTable'            => '0.43',
        'Proc::SafeExec'                => '1.4',
        'Prometheus::Tiny::Shared'      => '0.026',
        'Regexp::Common'                => '2',
        'SOAP::Lite'                    => 0,
        'SQL::Abstract::More'           => '1.38',      # OpenXPKI::Server::Database
        'Sys::SigAction'                => '0.06',
        'Template'                      => '2.15',
        'Test::More'                    => '1.001008',
        'Test::Pod::Coverage'           => '1.00',
        'Test::Pod'                     => '1.00',
        'Text::CSV_XS'                  => '0.23',
        'Time::HiRes'                   => '1',
        'Type::Tiny'                    => '2.000001',
        'URI::Escape'                   => 0,           # should be part of the core modules but who knows
        'Workflow'                      => '1.60',
        'YAML::Tiny'                    => '1.69',
    },
    'test' => {
        'TESTS' => 't/*/*.t',
    },
    'clean' => {
        'FILES' => [
            'OpenXPKI/VERSION.pm',
        ],
    },
    'XSPROTOARG' => '-noprototypes',
    'EXE_FILES' => [
        'bin/openxpkictl',
        'bin/openxpkicmd',
        'bin/openxpkiadm',
        'bin/openxpkicli',
        'bin/oxi',
    ],
    %flags,
);
