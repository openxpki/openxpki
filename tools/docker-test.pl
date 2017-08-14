#!/usr/bin/env perl
=pod

=head1 NAME

docker-test.pl - run OpenXPKI tests in a Docker container

=cut
use strict;
use warnings;

# Core modules
use Cwd qw( realpath getcwd );
use FindBin qw( $Bin );
use Getopt::Long;
use List::Util qw( sum );
use Pod::Usage;
use Symbol qw( gensym );
use IPC::Open3 qw( open3 );
use POSIX ":sys_wait_h";

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
my ($help, $commit, $branch, $repo, $test_all, @_only, $test_coverage, $batch);
my $parseok = GetOptions(
    'all'            => \$test_all,
    'only=s'         => \@_only,
    'cover|coverage' => \$test_coverage,
    'c|commit=s'     => \$commit,
    'b|branch=s'     => \$branch,
    'r|repo=s'       => \$repo,
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
    OXI_TEST_ONLY           => undef,
    OXI_TEST_ALL            => undef,
    OXI_TEST_COVERAGE       => undef,
    OXI_TEST_GITCOMMIT      => undef,
    OXI_TEST_GITREPO        => undef,
    OXI_TEST_GITBRANCH      => undef,
    OXI_TEST_NONINTERACTIVE => undef,
);
my @docker_args = ();

# Restricted set of tests specified?
$docker_env{OXI_TEST_ONLY}     = $test_only if $test_only;
$docker_env{OXI_TEST_ALL}      = $test_all if $test_all;
$docker_env{OXI_TEST_COVERAGE} = $test_coverage if $test_coverage;
$docker_env{OXI_TEST_NONINTERACTIVE} = 1 if $batch;

if ($repo) {
    $docker_env{OXI_TEST_GITREPO} = $repo =~ / \A [[:word:]-]+ \/ [[:word:]-]+ \Z /msx
        ? "https://dummy:nope\@github.com/$repo.git"
        : $repo;
}
# default to current branch in case of local repo
else {
    $branch ||= `git rev-parse --abbrev-ref HEAD`;
    chomp $branch;
    push @docker_args, "-v", "$project_root:/repo";
}

$docker_env{OXI_TEST_GITBRANCH} = $branch if $branch;
$docker_env{OXI_TEST_GITCOMMIT} = $commit if $commit;

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
    print "(This might take more than 10 minutes on first execution)\n";

    # Make scripts accessible for "docker build" (Dockerfile).
    # Without "--append" Docker would always see a new file and rebuild the image
    my $tar_mode = -f "$Bin/docker-test/scripts.tar" ? '--update' : '--create';
    my $olddir = getcwd; chdir $Bin;
    `tar $tar_mode -f "$Bin/docker-test/scripts.tar" scripts testenv`;
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
    qatest/backend/api/

or file name:

    core/server/t/31_database/01-base.t
    # same as:  t/31_database/01-base.t
    qatest/backend/api/10_list_profiles.t

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
