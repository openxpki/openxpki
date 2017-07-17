#!/usr/bin/perl

# Obeyed env variables:
#    OXI_TEST_ONLY      (Str: comma separated list of tests dirs/files)
#    OXI_TEST_ALL       (Bool: 1 = run all tests)
#    OXI_TEST_COVERAGE  (Bool: 1 = only run coverage tests)
#    OXI_TEST_GITREPO   (Str: Git repository)
#    OXI_TEST_GITBRANCH (Str: Git branch, default branch if not specified)

use strict;
use warnings;

# Core modules
use Cwd qw( realpath );
use File::Copy;
use File::Path qw( make_path );
use FindBin qw( $Bin );
use Getopt::Long;
use IPC::Open3 qw( open3 );
use List::Util qw( sum );
use Pod::Usage;
use POSIX ":sys_wait_h";
use Symbol qw( gensym );

# Exit handler - run bash on errors to allow inspection of log files
#
sub _exit {
    my ($start_bash, $code, $msg) = @_;
    if ($start_bash) {
        print STDERR "\n==========[ ERROR ]==========\n";
        print STDERR "$msg\n" if $msg;
        print STDERR "You may now inspect the log files below /var/log/openxpki/\n";
        print STDERR "To finally stop the Docker container type 'exit'.\n\n";
        system "/bin/bash", "-l";
    }
    else {
        print STDERR "\n$msg\n\n" if $msg;
    }
    exit $code;
}

sub _failure {
    my ($die_on_error, $code, $msg) = @_;
    return $code unless $die_on_error;
    my $start_bash = not $ENV{OXI_TEST_NONINTERACTIVE};
    _exit $start_bash, $code, $msg;
}

sub _stop {
    my ($code, $msg) = @_;
    _exit 0, $code, $msg;
}

# $mode:
#   code    - hide output and return exit code
#   capture - hide output and return it as string instead, exit on errors
#   show    - show output and return nothing, exit on errors
sub execute {
    my ($mode, $args, $tolerate_errors) = @_;
    $args = [ split /\s+/, $args ] unless ref $args eq "ARRAY";

    my $output = ($mode eq "show") ? ">&STDOUT" : gensym; # gensym = filehandle
    # execute command and wait for it to finish
    my $pid = open3(0, $output, 0, @$args);
    waitpid($pid, 0);

    my $die_on_error = not ($mode eq "code" or $tolerate_errors);
    my $output_str = ref $output eq "GLOB" ? do { local $/; <$output> } : "";
    return _failure($die_on_error, -1) if $? == -1; # execute failed: error message was already shown by system()
    return _failure($die_on_error, $? & 127, sprintf( "'%s' died with signal %d: %s", $args->[0], ($? & 127), $output_str )) if ($? & 127);
    return _failure($die_on_error, $? >> 8,  sprintf( "'%s' exited with code %d: %s", $args->[0], $? >> 8,    $output_str )) if ($? >> 8);

    return if $mode eq "show";
    return $output_str if $mode eq "capture";
    return 0;
}

my $clone_dir = "/opt/openxpki";
my @test_only = split ",", $ENV{OXI_TEST_ONLY};

my $mode = $ENV{OXI_TEST_ALL} ? "all" : (
    $ENV{OXI_TEST_COVERAGE} ? "coverage" : "selected"
);

my @tests_unit;
my @tests_qa;
if ($mode eq "all") {
    @tests_unit = "t/";
    # testing api/ before nice/ leads to errors!
    @tests_qa   = qw( qatest/backend/nice qatest/backend/api qatest/backend/webui );
}
elsif ($mode eq "selected") {
    my @tests = split /,/, $ENV{OXI_TEST_ONLY};
    @tests_unit = grep { /^t\// } map { $_ =~ s/ ^ core\/server\/ //x; $_ } @tests;
    @tests_qa   = grep { /^qatest\// } @tests;
}

#
# Info
#
print  "\n.--==##[ Run tests in Docker container ]##==\n";
printf "| Repo:   %s\n", $ENV{OXI_TEST_GITREPO} ? $ENV{OXI_TEST_GITREPO} : "local";
printf "| Branch: %s\n", $ENV{OXI_TEST_GITBRANCH} // "(default)";
printf "| Commit: %s\n", $ENV{OXI_TEST_GITCOMMIT} // "HEAD";
my $msg = $ENV{OXI_TEST_ALL} ? " all tests" : ($ENV{OXI_TEST_COVERAGE} ? " code coverage" : " selected tests:");
my $big_msg = `figlet '$msg'`; $big_msg =~ s/^/| /msg;
print $big_msg;
printf "|      - $_\n" for @test_only;
print  "|\n";
print  ".--==#####################################==\n";

#
# Repository clone
#
my $repo;
my $is_local_repo = 0;
# remote repo as specified
if ($ENV{OXI_TEST_GITREPO}) {
    $repo = $ENV{OXI_TEST_GITREPO};
    _stop 100, "Sorry, local repositories specified by file:// are not supported:\n$repo"
        if $repo =~ / \A file /msx;
}
# local repo from host (if Docker volume is mounted)
else {
    # check if /repo is a mountpoint (= dev number differs from parent dir)
    _stop 101, "I need either a remote or local Git repo:\ndocker run -e OXI_TEST_GITREPO=https://...\ndocker run -v /my/path:/repo"
        unless ((stat "/repo")[0]) != ((stat "/")[0]);
    $repo = "file:///repo";
    $is_local_repo = 1;
}

_stop 103, "Code coverage tests only work with local repo" if ($mode eq "coverage" and not $is_local_repo);

print "\n====[ Git checkout ]====\n";
print "Testing repo\n";
my $code = execute code => [ "git", "ls-remote", "-h", $repo ];
_stop 104, "Remote repo either does not exist or is not readable" if $code;

# clone repo
print "Cloning repo\n";
my @branch_spec = $ENV{OXI_TEST_GITBRANCH} ? "--branch=".$ENV{OXI_TEST_GITBRANCH} : ();
my @restrict_depth = $ENV{OXI_TEST_GITCOMMIT} ? () : ("--depth=1");
execute capture => [ "git", "clone", @restrict_depth, @branch_spec, $repo, $clone_dir ];
if ($ENV{OXI_TEST_GITCOMMIT}) {
    print "Checking out commit $ENV{OXI_TEST_GITCOMMIT}\n";
    chdir $clone_dir;
    execute capture => [ "git", "checkout", $ENV{OXI_TEST_GITCOMMIT} ];
}

#
# Grab and install Perl module dependencies from Makefile.PL using PPI
#
print "\n====[ Scanning Makefile.PL for new Perl dependencies ]====\n";
my $cpanfile = execute capture => "/tools-copy/scripts/makefile2cpanfile.pl $clone_dir/core/server/Makefile.PL";
open my $fh, ">", "$clone_dir/cpanfile";
print $fh $cpanfile;
close $fh;

execute show => "cpanm --quiet --notest --installdeps $clone_dir";

#
# Database setup
#
print "\n====[ MySQL ]====\n";
my $dummy = gensym;
my $pid = open3(0, $dummy, 0, qw(sh -c mysqld) );
execute show => "/tools-copy/testenv/mysql-wait-for-db.sh";
execute show => "/tools-copy/testenv/mysql-create-user.sh";
# if there are only qatests, we create the database later on
if ($mode eq "coverage" or scalar @tests_unit) {
    execute show => "/tools-copy/testenv/mysql-create-db.sh";
    execute show => "/tools-copy/testenv/mysql-create-schema.sh $clone_dir/config/sql/schema-mysql.sql";
}

#
# OpenXPKI compilation
#
print "\n====[ Compile OpenXPKI ]====\n";
## Config::Versioned reads USER env variable
#export USER=dummy

chdir "$clone_dir/core/server";
`perl Makefile.PL`;
`make`;

#
# Test coverage
#
if ($mode eq "coverage") {
    print "\n====[ Testing the code coverage (this will take a while) ]====\n";
    my $code = execute code => "cover -test";
    print "Please note that some unit tests did not pass\n" if $code != 0;
    use DateTime;
    my $dirname = "code-coverage-".DateTime->new->strftime('%Y%m%d-%H%M%S');
    move "./cover_db", "/repo/$dirname";
    `chmod -R g+w,o+w "/repo/$dirname`;
    print "\nCode coverage results available in project root dir:\n$dirname\n";
    exit;
}

#
# Unit tests
#
if (scalar @tests_unit) {
    print "\n====[ Testing: unit tests ]====\n";
    execute show => "prove -b -r -q $_" for @tests_unit;
}

exit unless scalar @tests_qa;

#
# OpenXPKI installation
#
print "\n====[ Install OpenXPKI ]====\n";
print "Copying files\n";
`make install`;

# directory list borrowed from /package/debian/core/libopenxpki-perl.dirs
make_path "/var/openxpki/session", "/var/log/openxpki";

# copy config
`cp -R $clone_dir/config/openxpki /etc`;

# customize config
use File::Slurp qw( edit_file );
edit_file { s/ ^ ( (user|group): \s+ ) \w+ /$1root/gmsx } "/etc/openxpki/config.d/system/server.yaml";
execute show => "/tools-copy/testenv/mysql-oxi-config.sh";

#
# Database (re-)creation
#
execute show => "/tools-copy/testenv/mysql-create-db.sh";
execute show => "/tools-copy/testenv/mysql-create-schema.sh $clone_dir/config/sql/schema-mysql.sql";

#
# Sample config (CA certificates etc.)
#
execute show => "/tools-copy/testenv/insert-certificates.sh";

#
# Start OpenXPKI
#
execute show => "/usr/local/bin/openxpkictl start";

#
# QA tests
#
print "\n====[ Testing: QA tests ]====\n";
chdir "$clone_dir/qatest";
my @t = map { $_ =~ s/ ^ qatest\/ //x; $_ } @tests_qa;
execute show => "prove -l -r -q $_" for @t;
