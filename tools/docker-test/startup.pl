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
use File::Temp qw( tempdir );
use FindBin qw( $Bin );
use Getopt::Long;
use IPC::Open3 qw( open3 );
use List::Util qw( sum );
use Pod::Usage;
use POSIX ":sys_wait_h";
use Symbol qw( gensym );

#
# Configuration
#
my $clone_dir = "/opt/openxpki";
my $config_dir = $ENV{'OXI_TEST_SAMPLECONFIG_DIR'} || die "OXI_TEST_SAMPLECONFIG_DIR is not set";

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
    return _failure(!$tolerate_errors, $? & 127, sprintf( "'%s' died with signal %d: %s", $args->[0], ($? & 127), $output_str )) if ($? & 127);
    return _failure($die_on_error, $? >> 8,  sprintf( "'%s' exited with code %d: %s", $args->[0], $? >> 8, $output_str )) if ($? >> 8);

    return if $mode eq "show";
    return $output_str if $mode eq "capture";
    return 0;
}

sub git_checkout {
    my ($env_repo, $dir_repo, $branch, $commit, $target) = @_;

    my $repo;
    my $is_local = 0;
    # remote repo as specified
    if ($ENV{$env_repo}) {
        $repo = $ENV{$env_repo};
        _stop 100, "Sorry, local repositories specified by file:// are not supported.\nUse this instead:\ndocker run -v /my/host/path:$dir_repo ..."
            if $repo =~ / \A file /msx;
    }
    # local repo from host (if Docker volume is mounted)
    else {
        # only continue if $dir_repo is a mountpoint (= device number differs from parent dir)
        _stop 101, "Please specify either a remote or local Git repo:\ndocker run -e $env_repo=https://...\ndocker run -v /my/host/path:$dir_repo"
            unless (-d $dir_repo and (stat $dir_repo)[0] != (stat "/")[0]);
        $repo = "file://$dir_repo";
        $is_local = 1;
    }

    my $code = execute code => [ "git", "ls-remote", "-h", $repo ];
    _stop 104, "Repo $repo either does not exist or is not readable" if $code;

    #
    # Clone repository
    #
    print "- Cloning repo into $target ... ";
    my @branch_spec = $branch ? "--branch=$branch" : ();
    my @restrict_depth = $commit ? () : ("--depth=1");
    execute capture => [ "git", "clone", @restrict_depth, @branch_spec, $repo, $target ];
    if ($commit) {
        print "Checking out given commit... ";
        chdir $target;
        execute capture => [ "git", "checkout", $commit ];
    }
    print "\n";

    #
    # Informations
    #
    printf "  Repo:   %s\n", $is_local ? "local" : $ENV{$env_repo};
    printf "  Branch: %s\n", $branch // "(default)";
    printf "  Commit: %s\n", $commit // "HEAD";

    # last commit's message
    chdir $target;
    my $logmsg = execute capture => [ "git", "log", "--format=%B", "-n" => 1, $commit // "HEAD", ];
    $logmsg =~ s/\R$//gm;            # remove trailing newline
    ($logmsg) = split /\R/, $logmsg; # only print first line
    printf "          » %s «\n", $logmsg;

    return $is_local;
}



my $mode = "all"; # default mode
$mode = "all" if $ENV{OXI_TEST_ALL};
$mode = "coverage" if $ENV{OXI_TEST_COVERAGE};
my @test_only = split ",", $ENV{OXI_TEST_ONLY};
$mode = "selected" if scalar @test_only;

my @tests_unit;
my @tests_qa;
if ($mode eq "all") {
    @tests_unit = "t/";
    @tests_qa   = qw( qatest/backend/api2 qatest/backend/webui qatest/client );
}
elsif ($mode eq "selected") {
    @tests_unit = grep { /^t\// } map { my $t = $_; $t =~ s/ ^ core\/server\/ //x; $t } @test_only;
    @tests_qa   = grep { /^qatest\// } @test_only;
}

#
# Test arguments and repository
#
print "\n####[ Run tests in Docker container ]####\n";

#
# Code repository
#
print "\nCode source:\n";
my $local_repo = git_checkout('OXI_TEST_GITREPO', '/repo', $ENV{OXI_TEST_GITBRANCH}, $ENV{OXI_TEST_GITCOMMIT}, $clone_dir);
_stop 103, "Code coverage tests only work with local repo" if ($mode eq "coverage" and not $local_repo);

#
# Config repository
#
print "\nConfiguration source:\n";
my $config_gitbranch = $ENV{OXI_TEST_CONFIG_GITBRANCH};
# auto-set config branch to develop if code is based on develop
if (not $config_gitbranch) {
    print "- no Git branch specified, auto-detecting if code is based on 'develop': ";
    my $temp_coderepo = tempdir( CLEANUP => 1 );
    # get commit id of branch "develop" in official repo
    `git clone --quiet --depth=1 --branch=develop https://github.com/openxpki/openxpki.git $temp_coderepo`;
    chdir $temp_coderepo;
    my $commit_id_develop=`git rev-parse HEAD`;

    chdir $clone_dir;
    my $exit_code = execute code => [ 'git', 'merge-base', '--is-ancestor', $commit_id_develop, 'HEAD' ];

    # exit codes: 1 = develop is no ancestor of HEAD, 128 = commit ID not found
    $config_gitbranch = $exit_code == 0 ? 'develop' : 'master';
    print $exit_code == 0 ? "yes\n" : "no\n";
}
git_checkout('OXI_TEST_CONFIG_GITREPO', '/config', $config_gitbranch, $ENV{OXI_TEST_CONFIG_GITCOMMIT}, $config_dir);

#
# List selected tests
#
print "\n";
my $msg = $mode eq "all" ? " all tests" : ($mode eq "coverage" ? " code coverage" : " selected tests:");
print `figlet '$msg'`;
printf " - $_\n" for @test_only;

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
    execute show => "/tools-copy/testenv/mysql-create-schema.sh $clone_dir/config/contrib/sql/schema-mysql.sql";
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
    execute show => "cover -test";
    use DateTime;
    my $dirname = "code-coverage-".(DateTime->now->strftime('%Y%m%d-%H%M%S'));
    my $cover_src = "$clone_dir/core/server/cover_db";
    my $cover_target = "/repo/$dirname";
    if (-d $cover_src) {
        system "mv", $cover_src, $cover_target;
        if (-d $cover_target) {
            `chmod -R g+w,o+w "$cover_target"`;
            print "\nCode coverage results available in project root dir:\n$dirname\n";
        }
        else {
            print "\nError: code coverage results could not be moved to host dir $cover_target:\n$!\n"
        }
    }
    else {
        print "\nError: code coverage results where not found\n($cover_src does not exist)\n"
    }
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
`mkdir -p /etc/openxpki && cp -R $config_dir/* /etc/openxpki`;

# customize config
use File::Slurp qw( edit_file );
edit_file { s/ ^ ( (user|group): \s+ ) \w+ /$1root/gmsx } "/etc/openxpki/config.d/system/server.yaml";
execute show => "/tools-copy/testenv/mysql-oxi-config.sh";

#
# Database (re-)creation
#
execute show => "/tools-copy/testenv/mysql-create-db.sh";
execute show => "/tools-copy/testenv/mysql-create-schema.sh $config_dir/contrib/sql/schema-mysql.sql";

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
my @t = map { my $t = $_; $t =~ s/ ^ qatest\/ //x; $t } @tests_qa;
execute show => "prove -l -r -q $_" for @t;
