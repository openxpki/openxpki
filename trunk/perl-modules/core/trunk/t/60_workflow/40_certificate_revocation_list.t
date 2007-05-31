use strict;
use warnings;
use English;
use Test::More qw( no_plan );

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

# this is needed because we need to manually output the number of tests run
Test::More->builder()->no_header(1);
my $OUTPUT_AUTOFLUSH = 1;
my $NUMBER_OF_TESTS  = 8;

# do not use test numbers because forking destroys all order
Test::More->builder()->use_numbers(0);

diag("Certificate revocation list workflow\n");
print "1..$NUMBER_OF_TESTS\n";

my $instancedir = 't/60_workflow/test_instance_crl';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

ok(deploy_test_server({
        DIRECTORY  => $instancedir,
    }), 'Test server deployed successfully');
ok(create_ca_cert({
        DIRECTORY => $instancedir,
    }), 'CA certificate created and installed successfully');

# Fork server, connect to it, test config IDs, create workflow instance
my $redo_count = 0;
my $pid;
FORK:
do {
    $pid = fork();
    if (! defined $pid) {
        if ($!{EAGAIN}) {
            # recoverable fork error
            if ($redo_count > 5) {
                die "Forking failed";
            }
            sleep 5;
            $redo_count++;
            redo FORK;
        }

        # other fork error
        die "Forking failed: $ERRNO";
        last FORK;
    }
} until defined $pid;

if ($pid) {
    # this is the parent
    Test::More->builder()->use_numbers(0);
    start_test_server({
        FOREGROUND => 1,
        DIRECTORY  => $instancedir,
    });
}
else {
    Test::More->builder()->use_numbers(0);
    # child here

  CHECK_PIDFILE:
    foreach my $i (1..60) {
        if (-e $pidfile) {
            last CHECK_PIDFILE;
        }
        else {
            sleep 1;
        }
    }
    ok(-e $pidfile, "PID file exists");
    ok(-e $socketfile, "Socketfile exists");
    my $client = OpenXPKI::Client->new({
        SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
    });
    ok(login({
        CLIENT   => $client,
        USER     => 'raop',
        PASSWORD => 'RA Operator',
      }), 'Logged in successfully');

    # New workflow instance
    my $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CRL_ISSUANCE',
            PARAMS   => {
            },
        },
    );
    ok(! is_error_response($msg), 'Successfully created CRL workflow instance');
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'SUCCESS', 'WF is in state SUCCESS');
    ok(-s "$instancedir/etc/openxpki/ca/testdummyca1/crl.pem", "CRL file exists");

    # LOGOUT
    eval {
        $msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";
    exit 0;
}
