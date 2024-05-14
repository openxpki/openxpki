#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp;

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ level => $ENV{TEST_VERBOSE} ? $DEBUG : $OFF, layout => '# %m%n' });

# Project modules
try {
    require OpenXPKI::Server::ProcTerminal;
}
catch ($err) {
    die $err unless $err =~ /^Can't locate/;
    plan skip_all => "OpenXPKI::Server::ProcTerminal (EE code) not available";
};

my $tempdir = File::Temp::tempdir(CLEANUP => 1);
my $testfile = "$tempdir/testfile";

my %config = (
    pid_file => "$tempdir/terminal.pid",
    socket_file => "$tempdir/terminal.sock",
    command => ['/bin/bash', '-c', "$Bin/bash-proc.sh $testfile" ],
    umask => '0077',
);

sub wait_for {
    my ($term, $expected) = @_;

    note "Waiting for: '$expected'";

    for (my $tries = 5; $tries > 0; $tries--) {
        my $all_output = $term->output;
        note join("\n", map { "<< $_" } split /\n/, $all_output);
        return 1 if ($all_output =~ /\Q$expected\E/);
        sleep 1;
    }
    die "Timeout waiting for expected output\n";
}

sub run_tests {
    my ($term, $control, $testfile, $internal) = @_;

    lives_and { ok !$control->check_server(verbose => 1) } "no server";

    if (not $internal) {
        dies_ok { $term->run } qr/Cannot create socket/;
        lives_ok { $control->start_server } "externally start daemon";
    }

    lives_and { ok !$term->is_running } "no external process";

    lives_ok { $term->run } "start external process";
    lives_and { ok $term->is_running } "external process is running";

    lives_ok { $term->run } "ignore attempt to start another external process";

    lives_and { ok $control->check_server(verbose => 1, check_socket => 1) } "server is running";

    lives_ok {
        wait_for($term, 'password #1');
        $term->input("pwd:1\n");
        #note ">> pwd:1";
        wait_for($term, 'PASSWORD_OK');
    } "correct password gets accepted";

    lives_ok {
        wait_for($term, 'password #2');
        $term->input("pwd:2\n");
        #note ">> pwd:2";
        wait_for($term, 'PASSWORD_WRONG');
    } "wrong password gets rejected";

    sleep 1 while ($term->is_running);

    lives_and { is $term->exit_code, 33 } "correct exit code";

    lives_ok { $term->stop_server } "stop server";
    lives_and {
        my ($runs, $i);
        while ($i++ < 3) {
            $runs = $control->check_server;
            last if not $runs;
            sleep 1;
        }
        ok not $runs;
    } "no server";

    ok -e $testfile, "testfile was created";
    my $mode = (stat($testfile))[2] & 07777; # & 07777 filters out file type
    is sprintf('%o', $mode), sprintf('%o', 0666 &~ oct($config{umask})), "testfile has correct permissions";
    ok unlink($testfile), "testfile was deleted";
}

my $ctx = OpenXPKI::Server::ProcTerminal->new(config => { test => { %config, internal => 1 } });

my $term;
my $control;

for my $internal (1, 0) {
    # launch daemon automatically via OpenXPKI
    if ($internal) {
        $term = $ctx->proc('test');
        $control = $term->control;
    }
    # launch daemon externally
    else {
        $control = OpenXPKI::Server::ProcTerminal::Control->new(
            name => 'test-external',
            %config,
        );

        $term = OpenXPKI::Server::ProcTerminal::Client->new(
            name => 'test-external',
            socket_file => $config{socket_file},
        );
    }

    subtest sprintf("Launch daemon %s", $internal ? 'automatically via OpenXPKI' : 'externally') => sub {
        run_tests($term, $control, $testfile, $internal);
    };
}

done_testing;
