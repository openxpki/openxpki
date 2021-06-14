#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use Log::Log4perl;
use Log::Log4perl::Appender;
use Log::Log4perl::Layout::NoopLayout;
use Log::Log4perl::Level;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 7;


my $maxage = 60*60*24;  # 1 day
my $loglevel = 'INFO';
my $loglevel_int = Log::Log4perl::Level::to_priority($loglevel);

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    log_level => $loglevel,
    enable_workflow_log => 1, # while testing we do not log to database by default
);

## add database logger
#my $appender = Log::Log4perl::Appender->new(
#    "OpenXPKI::Server::Log::Appender::Database",
#    layout   => Log::Log4perl::Layout::NoopLayout->new(),
#    table => "application_log",
#    microseconds => 1,
#);
#Log::Log4perl->get_logger("openxpki.application")->add_appender($appender);


sub is_logentry_count {
    my ($wf_id, $count) = @_;

    my $result = $oxitest->dbi->select_hashes(
        from => 'application_log',
        columns => [ '*' ],
        where => {
            category => 'openxpki.application',
            workflow_id => $wf_id,
        }
    );

    is scalar @{$result}, $count, "$count log entries found via workflow id";
}

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

my $result = $dbi->select_hashes(
    from => 'application_log',
    columns => [ '*' ],
    where => {
        category => 'openxpki.application',
        message => { -like => "%$msg" },
    }
);

cmp_deeply $result, superbagof(superhashof({
    workflow_id => $wf_id,
    priority => $loglevel_int,
})), "log entry found via string search";

# Insert test message #1 via database
ok $dbi->insert_and_commit(
    into => 'application_log',
    values => {
        application_log_id  => $dbi->next_id('application_log'),
        logtimestamp        => time - $maxage + 5, # should be kept when calling 'purge'
        workflow_id         => $wf_id,
        category            => 'openxpki.application',
        priority            => $loglevel_int,
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
        priority            => $loglevel_int,
        message             => "Blah",
    },
), "insert old test message to be purged";

is_logentry_count $wf_id, 3;

# API call to purge records
lives_and {
    ok $oxitest->api2_command("purge_application_log" => { maxage => $maxage });
} "call 'purge_application_log' with 'maxage'";

is_logentry_count $wf_id, 2;

1;
