#!/usr/bin/env perl
#
# Regression test: create_workflow_instance() with "norun => detach" must run
# the initial action as role "System" even if the caller has a Memory session
# (watchdog process, detached child), and persist that role for later wakeups.
#
use strict;
use warnings;

# The forked child of _execute_activity_async() ends with exit(), which would
# end this test. Must be installed before the code calling exit() is compiled.
BEGIN {
    *CORE::GLOBAL::exit = sub { die "TEST_CHILD_EXIT\n" };
}

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Exception;
use JSON::PP;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Bedroom; # must be loaded before we redefine new_child()
use OpenXPKI::Server;
use OpenXPKI::Server::Session;
use OpenXPKI::Test;

plan tests => 9;

my $workflow_type = "TESTWORKFLOW".int(rand(2**32));
my $wf = "realm.alpha.workflow.def.$workflow_type";

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms ) ],
    also_init => "workflow_factory",
    add_config => {
        "$wf" => "
            acl:
                MyFairyKing:
                    creator: any
                System:
                    creator: any

            state:
                INITIAL:
                    action: noop > SUCCESS

                SUCCESS: {}

            action:
                noop:
                    class: OpenXPKI::Server::Workflow::Activity::Noop
        ",

        "$wf.head" => "
            prefix: testwf
            persister: OpenXPKI
        ",
    },
);

#
# Run the CHILD branch of _execute_activity_async() in this process instead of
# really forking (a real fork() would duplicate the TAP output stream).
# OpenXPKI::Server->cleanup would disconnect the test's database handle.
#
my $forked = 0;
{
    no warnings 'redefine';
    no strict 'refs';
    *{"OpenXPKI::Server::Bedroom::new_child"} = sub { $forked++; return 0 };
    *{"OpenXPKI::Server::cleanup"} = sub {};
}

# Creates a detached workflow with the given caller session and returns the
# user/role stored with the workflow (what the watchdog restores on wakeup)
sub stored_session_of {
    my ($session, $label) = @_;

    $session->data->pki_realm($oxitest->session->data->pki_realm);
    $session->data->user("wfcreator");
    $session->data->role("MyFairyKing");
    OpenXPKI::Server::Context::setcontext({ session => $session, force => 1 });

    $forked = 0;
    CTX('dbi')->start_txn;

    throws_ok {
        CTX('api2')->create_workflow_instance(
            workflow => $workflow_type,
            norun    => 'detach',
            _run_as_system => 1,
        );
    } qr/TEST_CHILD_EXIT/, "$label: detached child ran and exited";

    is $forked, 1, "$label: activity was dispatched to a (simulated) forked process";

    my $row = $oxitest->dbi->select_one(
        from    => 'workflow',
        columns => [ qw( workflow_id workflow_state workflow_session ) ],
        where   => { workflow_type => $workflow_type },
    );

    is $row->{workflow_state}, 'SUCCESS', "$label: initial action was executed";

    my $id = $row->{workflow_id};
    for my $table (qw( workflow_attributes workflow_history workflow_context workflow )) {
        $oxitest->dbi->delete_and_commit(from => $table, where => { workflow_id => $id });
    }

    return $row->{workflow_session} ? decode_json($row->{workflow_session}) : {};
}

# The watchdog after Watchdog::__restore_session(): a Memory session holding
# the user and role of the workflow that is being woken up
is_deeply stored_session_of(
    OpenXPKI::Server::Session->new(type => "Memory")->create, "Memory session"
), { user => 'wfcreator', role => 'System' },
    "Memory session: workflow was persisted with role System";

# The service layer (e.g. WebUI)
my $db_session = OpenXPKI::Server::Session->new(load_config => 1)->create;
isnt $db_session->type, 'Memory', "test config provides a non-Memory session";
is_deeply stored_session_of($db_session, "Database session"),
    { user => 'wfcreator', role => 'System' },
    "Database session: workflow was persisted with role System";

1;
