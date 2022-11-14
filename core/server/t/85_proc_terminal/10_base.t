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
use Test::Deep;
use Test::Exception;
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ level => $OFF });
#Log::Log4perl->easy_init({ level => $TRACE, file => '>>/tmp/oxi-proc-terminal.log', layout => '%-5p %P %C | %m%n' });

# Project modules
try {
    require OpenXPKI::Server::ProcTerminal::Client;
    require OpenXPKI::Server::ProcTerminal::Control;
}
catch ($err) {
    plan skip_all => "OpenXPKI::Server::ProcTerminal::Client (EE code) not available. Message was: $err";
};

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

my $tempdir = File::Temp::tempdir(CLEANUP => 1);

my $control = OpenXPKI::Server::ProcTerminal::Control->new(
    name => 'test',
    server_pidfile => "$tempdir/terminal.pid",
    socket_file => "$tempdir/terminal.sock",
    system_command => ['/bin/bash', '-c', "$Bin/bash-proc.sh" ],
);

my $term = OpenXPKI::Server::ProcTerminal::Client->new(
    name => 'test',
    server_controller => $control,
    socket_file => "$tempdir/terminal.sock",
);

lives_and { ok !$control->check_server } "no server";
lives_and { ok !$term->is_running } "no external process";

lives_ok { $term->run } "start external process";
lives_and { ok $term->is_running } "external process is running";

lives_ok { $term->run } "ignore attempt to start another external process";

lives_and { ok $control->check_server } "server is running";

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
lives_and { ok !$control->check_server } "no server";

done_testing;
