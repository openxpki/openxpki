#!/usr/bin/env perl
=pod

=head1 NAME

docker-test.pl - run OpenXPKI tests in a Docker container

=cut
use strict;
use warnings;

# Core modules
use Cwd qw( realpath getcwd );
use File::Copy;
use File::Temp qw( tempdir );
use FindBin qw( $Bin );
use Getopt::Long;
use IPC::Open3 qw( open3 );
use List::Util qw( sum );
use Pod::Usage;
use POSIX ":sys_wait_h";
use Symbol qw( gensym );

# $interactive
#   1 = STDIN can be used for input
#   0 = output will be hidden if execution takes less than 5 seconds
sub execute {
    my ($args, $interactive) = @_;

    my $pid;
    my $output;
    if ($interactive) {
        $pid = open3("<&STDIN", ">&STDOUT", 0, @$args);
    }
    else {
        $output = gensym; # filehandle
        $pid = open3(0, $output, 0, @$args);
    }
    my $tick = 0;
    my $kid;
    while (not $kid) {
        # show output if command takes more than 5 sec
        if (not $interactive and $tick > 5) {
            while( my $lines = <$output> ) { print "$lines" }
        }
        $kid = waitpid($pid, WNOHANG); # wait for command to exit
        last if $kid;
        sleep 1; $tick++;
    };

    exit 1 if $? == -1; # execute failed: error message was already shown by system()

    my $lines = ""; $lines = do { local $/; $lines = <$output> || "" } unless $interactive;
    die sprintf "ERROR - '%s' died with signal %d\n%s\n", $args->[0], ($? & 127), $lines if ($? & 127);
    die sprintf "ERROR - '%s' exited with code %d\n%s\n", $args->[0], $? >> 8, $lines   if ($? >> 8);
}

my $project_root = realpath("$Bin/../");

#
# Parse command line arguments
#
my ($help, $repo, $branch, $commit, $conf_repo, $conf_branch, $conf_commit, $test_all, @_only, $test_coverage, $batch);
my $parseok = GetOptions(
    'all'            => \$test_all,
    'only=s'         => \@_only,
    'cover|coverage' => \$test_coverage,
    'c|commit=s'     => \$commit,
    'b|branch=s'     => \$branch,
    'r|repo=s'       => \$repo,
    'confrepo=s'     => \$conf_repo,
    'confbranch=s'   => \$conf_branch,
    'confcommit=s'   => \$conf_commit,
    'batch'          => \$batch,
    'help'           => \$help,
);

my $test_only = join ',', @_only;

pod2usage(-exitval => 1, -verbose => 0)
    unless ($parseok and ($test_all or $test_only or $test_coverage or $help));

pod2usage(-exitval => 0, -verbose => 2) if $help;

my $mode_switches = sum ( map { $_ ? 1 : 0 } ($test_all, $test_only, $test_coverage) );
die "ERROR: Please specify only one of: --all | --only | --cover\n" if $mode_switches > 1;

#
# Construct Docker arguments
#
my %docker_env = (
    OXI_TEST_ONLY => undef,
    OXI_TEST_ALL => undef,
    OXI_TEST_COVERAGE => undef,
    OXI_TEST_GITREPO => undef,
    OXI_TEST_GITBRANCH => undef,
    OXI_TEST_GITCOMMIT => undef,
    OXI_TEST_CONFIG_GITREPO => undef,
    OXI_TEST_CONFIG_GITBRANCH => undef,
    OXI_TEST_CONFIG_GITCOMMIT => undef,
    OXI_TEST_NONINTERACTIVE => undef,
);
my @docker_args = ();

# Restricted set of tests specified?
$docker_env{OXI_TEST_ONLY}     = $test_only if $test_only;
$docker_env{OXI_TEST_ALL}      = $test_all if $test_all;
$docker_env{OXI_TEST_COVERAGE} = $test_coverage if $test_coverage;
$docker_env{OXI_TEST_NONINTERACTIVE} = 1 if $batch;

sub normalize_repo {
    my ($repo) = @_;
    return $repo =~ / \A [[:word:]-]+ \/ [[:word:]-]+ \Z /msx
        ? "https://github.com/$repo.git"
        : $repo;
}

sub get_branch_commit {
    my ($dir) = @_;
    my ($branch, $commit);

    chdir($dir);

    $branch ||= `git rev-parse --abbrev-ref HEAD`;
    chomp $branch;
    # if we are currently in a detached head (i.e. no branch name)
    if ($branch eq 'HEAD') {
        $commit = `git rev-parse --short HEAD`; # get commit ID
        chomp $commit;
        $branch = undef;
    }
    return ($branch, $commit);
}

#
# Code repository
#
my $is_local_repo = 0;
if ($repo) {
    $docker_env{OXI_TEST_GITREPO} = normalize_repo($repo);
}
# default to current branch in case of local repo
else {
    ($branch, $commit) = get_branch_commit($project_root);
    push @docker_args, "-v", "$project_root:/repo";
    $is_local_repo = 1;
}

$docker_env{OXI_TEST_GITBRANCH} = $branch if $branch;
$docker_env{OXI_TEST_GITCOMMIT} = $commit if $commit;

#
# Configuration repository
#
if ($conf_repo) {
    $docker_env{OXI_TEST_CONFIG_GITREPO} = normalize_repo($conf_repo);
}
# default to current branch in case of local repo
else {
    $docker_env{OXI_TEST_CONFIG_GITREPO} = normalize_repo('openxpki/openxpki-config');

    # use local config commit only if also local code repo is used
    my $conf_dir = "$project_root/config";
    if ($is_local_repo and -e "$conf_dir/config.d/system/server.yaml") {
        ($conf_branch, $conf_commit) = get_branch_commit($conf_dir);
        # Pleas note:
        # config/ is most probably only a Git sub-module and thus could not be accessed
        # from within the container if we pass "-v $conf_dir:/config" to Docker
    }
}

$docker_env{OXI_TEST_CONFIG_GITBRANCH} = $conf_branch if $conf_branch;
$docker_env{OXI_TEST_CONFIG_GITCOMMIT} = $conf_commit if $conf_commit;


push @docker_args,
    map {
        $docker_env{$_}
            ? ("-e", sprintf "%s=%s", $_, $docker_env{$_})
            : ()
    }
    sort keys %docker_env;

#
# Build container
#
print "\n====[ Build Docker image ]====\n";
my @cmd;
if ($batch) {
    print "Skipping (batch mode)\n";
}
else {
    `which sha256sum` or die "Sorry, I need the 'sha256sum' command line tool\n";

    print "(might take more than 10 minutes when first run on a new host)\n";
    # Make scripts accessible for "docker build" (Dockerfile).
    # Only update TAR file if neccessary to prevent Docker from always rebuilding the image
    my $tarfile = "$Bin/docker-test/scripts.tar";
    my $olddir = getcwd; chdir $Bin;
    # keep existing TAR file (and its timestamp) unless there were changes
    if (-f $tarfile) {
        # create a temp TAR file and compare checksums
        `tar --create -f "$tarfile.new" scripts testenv`;
        (my $checksum_old = `sha256sum "$tarfile"`) =~ s/^(\S+)\s+.*/$1/s;
        (my $checksum_new = `sha256sum "$tarfile.new"`) =~ s/^(\S+)\s+.*/$1/s;
        if ($checksum_new ne $checksum_old) {
            move("$tarfile.new", $tarfile);
        }
        else {
            unlink "$tarfile.new";
        }
    }
    else {
        `tar --create -f "$tarfile" scripts testenv`;
    }
    chdir $olddir;

    @cmd = ( qw( docker build -t oxi-test ), "$Bin/docker-test");
    execute \@cmd;
}

#
# Run container
#
@cmd = ( qw( docker run -it --rm ), @docker_args, "oxi-test" );
printf "\nExecuting: %s\n", join(" ", @cmd);
execute \@cmd, 1;

__END__

=head1 SYNOPSIS

docker-test.pl --all           [Options]

docker-test.pl --only TESTSPEC [Options]

docker-test.pl --cover         [Options]

docker-test.pl --help

Modes:

    --all
        Run all unit and QA tests

    --only TESTSPEC
        Run only the given tests (option can be specified multiple times)

    --cover
        Run code coverage tests instead of normal tests and copy the directory
        containing the test results into the root of the local repository
        (code-coverage-YYMMDD-HHMMSS)

Options:

    -c COMMIT
    --commit COMMIT
        Use the given COMMIT instead of "HEAD" (can be anything git understands)

    -b BRANCH
    --branch BRANCH
        Use the given BRANCH instead of the current (local repo) or the default
        (remote repo)

    -r REPO
    --repo REPO
        Use the given (remote) REPOsitory instead of the local one where we are
        currently in

    --batch
        Run the tests non-interactively in "batch"/"script" mode:
        1. Do not try to rebuild the Docker image
        2. In case of errors, do not open a shell in the container, just exit.

    --help
        Show full documentation

=head1 DESCRIPTION

Run unit and QA tests for OpenXPKI in a Docker container.

You need a working Docker installation to run this script.
On first execution a Docker image called "oxi-test" is built (might take
more than 10 minutes).
Then (on every call) a Docker container is created from the image in which
the repo is cloned and the tests are executed (takes a few minutes).

This means that nothing will be modified on your host system (in your local
repository) except for --coverage, in that case the results are copied over.

=head1 SYNTAX

=head2 TESTSPEC

Tests can be specified either by directory:

    core/server/t/31_database
    # same as:  t/31_database
    qatest/backend/api2/

or file name:

    core/server/t/31_database/01-base.t
    # same as:  t/31_database/01-base.t
    qatest/backend/api2/10_list_profiles.t

=head1 EXAMPLES

docker-test.pl --all

    Test the latest commit (not working dir!) of the current Git branch in your
    local repo.

docker-test.pl --only t/31_database --only t/45_session

    Only run database and session related unit tests.

docker-test.pl --coverage

    Test the code coverage using "cover -test".

docker-test.pl --all -b myfix

    Test latest commit of branch "myfix" in your local repo.

docker-test.pl --all -r openxpki/openxpki

    Test latest commit of default branch in Github repository "openxpki/openxpki".

docker-test.pl --all -r https://github.com/openxpki/openxpki.git

    Same as above.

=cut
