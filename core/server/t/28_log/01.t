use strict;
use warnings;

# Core modules
use Test::More tests => 5;
use File::Temp qw( tempfile );

use English;

my (undef, $openxpki_log) = tempfile(UNLINK => 1);
my (undef, $connector_log) = tempfile(UNLINK => 1);

my $log_conf = "
# Catch-all root logger
log4perl.rootLogger = ERROR, Logfile

## FACILITY: AUTH
log4perl.category.openxpki.auth = INFO, Logfile

## FACILITY: AUDIT
log4perl.category.openxpki.audit = INFO, Logfile, DBI

## FACILITY: MONITOR
log4perl.category.openxpki.monitor = INFO, Logfile

## FACILITY: SYSTEM
log4perl.category.openxpki.system = DEBUG, Logfile

## FACILITY: WORKFLOW
log4perl.category.openxpki.workflow = ERROR, Logfile

## FACILITY: Connector (outside OXI!)
log4perl.category.connector = DEBUG, Connector

log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = $openxpki_log
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d %c.%p %m%n

log4perl.appender.Connector          = Log::Log4perl::Appender::File
log4perl.appender.Connector.filename = $connector_log
log4perl.appender.Connector.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Connector.layout.ConversionPattern = %d %c.%p %m%n

log4perl.appender.DBI              = OpenXPKI::Server::Log::Appender::Database
log4perl.appender.DBI.layout       = Log::Log4perl::Layout::NoopLayout
log4perl.appender.DBI.warp_message = 0
";

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

BEGIN { use_ok "OpenXPKI::Server::Log" };

my $log = OpenXPKI::Server::Log->new(CONFIG => \$log_conf);

# Not logged
ok (! $log->log (FACILITY => "auth",
               PRIORITY => "debug",
               MESSAGE  => "I shall not be there"), 'Suppressed test message');

ok (! -s $openxpki_log, 'Log file has zero size');

# loggged

ok ($log->log (FACILITY => "auth",
               PRIORITY => "info",
               MESSAGE  => "See me"), 'Test message');

my $log_contents = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $fh, '<', $openxpki_log;
    <$fh>;
};

like $log_contents, qr/See me/, "Log file contains message";

1;
