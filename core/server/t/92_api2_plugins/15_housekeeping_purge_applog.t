#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use Log::Log4perl::Level;
# CPAN modules
use Test::More;

use lib "$Bin/../lib";

plan tests => 7;

my $maxage = 60*60*24;  # 1 day

use OpenXPKI::Debug;
$OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL} if $ENV{DEBUG_LEVEL};

sub is_logentry_count {
    my ($wf_id, $count) = @_;

    my $result = CTX('dbi')->select(
        from => 'application_log',
        columns => [ '*' ],
        where => {
            category => 'openxpki.application',
            workflow_id => $wf_id,
        }
    )->fetchall_arrayref({});

    is scalar @{$result}, $count, "$count log entries found via workflow id";
}

#
# Setup test context
#
use OpenXPKI::Test;
my $threshold_screen = $ENV{TEST_VERBOSE} ? 'INFO' : 'OFF';
my $oxitest = OpenXPKI::Test->new(
#    log_level => 'info',
    enable_workflow_log => 1, # while testing we do not log to database by default
);

my $dbi = $oxitest->dbi;
my $log = CTX('log');

#
# Tests
#

# Setup workflow ID which is part of the logged informations
my $wf_id = int(rand(10000000));
OpenXPKI::Server::Context::setcontext({
    workflow_id => $wf_id
});
Log::Log4perl::MDC->put('wfid', $wf_id);

# Insert and validate test message via API
my $msg = sprintf "DBI Log Workflow Test %01d", $wf_id;

ok $log->application->info($msg), 'log test message to be kept'
    or diag "ERROR: log=$log";

my $result = $dbi->select(
    from => 'application_log',
    columns => [ '*' ],
    where => {
        category => 'openxpki.application',
        message => { -like => "%$msg%" },
    }
)->fetchall_arrayref({});

is scalar @{$result}, 1, "1 log entry found via string search";

# Insert test message #1 via database
ok $dbi->insert_and_commit(
    into => 'application_log',
    values => {
        application_log_id  => $dbi->next_id('application_log'),
        logtimestamp        => time - $maxage + 5, # should be kept when calling 'purge'
        workflow_id         => $wf_id,
        category            => 'openxpki.application',
        priority            => Log::Log4perl::Level::to_priority( "INFO" ),
        message             => "Blah",
    },
), "insert old test message to be kept";

# Insert test message #2 via database
ok $dbi->insert_and_commit(
    into => 'application_log',
    values => {
        application_log_id  => $dbi->next_id('application_log'),
        logtimestamp        => time - $maxage - 5, # should be deleted when calling 'purge'
        workflow_id         => $wf_id,
        category            => 'openxpki.application',
        priority            => Log::Log4perl::Level::to_priority( "INFO" ),
        message             => "Blah",
    },
), "insert old test message to be purged";

is_logentry_count $wf_id, 3;

# API call to purge records
ok CTX('api2')->purge_application_log( maxage => $maxage ), "call 'purge_application_log' with MAXAGE";

is_logentry_count $wf_id, 2;

1;
