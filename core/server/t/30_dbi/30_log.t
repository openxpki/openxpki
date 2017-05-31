use strict;
use warnings;
use English;
use Test::More;

plan tests => 41;

TODO: {
    # TODO Rewrite test for log appender to use new DB layer
    todo_skip 'Rewrite test for log appender to use new DB layer', 41;

    use OpenXPKI::Debug;
    if ($ENV{DEBUG_LEVEL}) {
        $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
    }

    our $dbi;
    our $token;
    require 't/30_dbi/common.pl';

    use OpenXPKI::Server::Context;
    use OpenXPKI::Server::Log;

    OpenXPKI::Server::Context::setcontext({
        dbi_log => $dbi,
    });
    my $log = OpenXPKI::Server::Log->new( CONFIG => 't/30_dbi/log4perl.conf' );

    my $msg = sprintf "DBI Log Test %01d", rand(10000000);

    ok ($log->log (FACILITY => "audit",
                   PRIORITY => "info",
                   MESSAGE  => $msg), 'Test message');

     my $result = $dbi->select(
        TABLE => 'AUDITTRAIL',
        DYNAMIC =>
        {
            CATEGORY => {VALUE => 'openxpki.audit' },
            MESSAGE => {VALUE => "%$msg", OPERATOR => 'LIKE'},
        }
    );
    is(scalar @{$result}, 1, 'Log entry found');

    $msg = sprintf "DBI Log Workflow Test %01d", rand(10000000);
    OpenXPKI::Server::Context::setcontext({
        workflow_id => 12345
    });

    ok ($log->log (FACILITY => "application",
                   PRIORITY => "info",
                   MESSAGE  => $msg), 'Workflow Test message')
               or diag "ERROR: log=$log";

    $result = $dbi->select(
        TABLE => 'APPLICATION_LOG',
        DYNAMIC =>
        {
            CATEGORY => {VALUE => 'openxpki.application' },
            MESSAGE => {VALUE => "%$msg", OPERATOR => 'LIKE'},
        }
    );
    is(scalar @{$result}, 1, 'Log entry found');
    is($result->[0]->{WORKFLOW_SERIAL}, 12345, "Check that workflow id was set");
    isnt($result->[0]->{TIMESTAMP}, undef, "Check that timestamp was set");
    is($result->[0]->{PRIORITY}, 20000, "Check that the priority 'info' is saved as 20000");

    my %levels = (
        'fatal' => 50000,
        'error' => 40000,
        'warn'  => 30000,
        'info'  => 20000,
        'debug' => 10000,
        'bogus' => 50000,
    );

    foreach my $level ( sort keys %levels ) {
        # Check via our DBI.pm code
        $msg = sprintf "DBI Log Workflow Test %01d", rand(10000000);
        ok ($log->log (FACILITY => "application",
                PRIORITY => $level,
                MESSAGE  => $msg), '[' . $level . '] Workflow Test message')
            or diag "ERROR: log=$log ($@)";

        $result = $dbi->select(
            TABLE => 'APPLICATION_LOG',
            DYNAMIC =>
            {
                CATEGORY => {VALUE => 'openxpki.application' },
                MESSAGE => {VALUE => "%$msg", OPERATOR => 'LIKE'},
            }
        );
        is(scalar @{$result}, 1, '[' . $level . '] Log entry found');
        is($result->[0]->{WORKFLOW_SERIAL}, 12345, "[$level] Check that workflow id was set");
        isnt($result->[0]->{TIMESTAMP}, undef, "[$level] Check that timestamp was set");
        is($result->[0]->{PRIORITY}, $levels{$level}, "[$level] Check the priority value");
    }
}

1;
