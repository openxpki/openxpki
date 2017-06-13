package OpenXPKI::Server::Log::Appender::Database;


use strict;
use English;
use Log::Log4perl;
use Log::Log4perl::MDC;
use Log::Log4perl::Level;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # we must import "auto_id"

our @ISA = qw(Log::Log4perl::Appender);

my %LOGLEVELS = (
    ALL     => 0,
    TRACE   => 5000,
    DEBUG   => 10000,
    INFO    => 20000,
    WARN    => 30000,
    ERROR   => 40000,
    FATAL   => 50000,
    OFF     => (2 ** 31) - 1,
);

sub new {
    my($proto, %p) = @_;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;

    if ($p{table}) {
        $self->{table} = $p{table};
    } else {
        $self->{table} = 'application_log';
    }

    if (defined $p{microseconds}) {
        $self->{microseconds} = $p{microseconds};
    } else {
        $self->{microseconds} = 1;
    }

    return $self;
}

my $occupied = 0;
sub log {

    ##! 1:  'start'
    my $self    = shift;
    my $arg_ref = { @_ };

    ##! 128: 'arg_ref: ' . Dumper $arg_ref

    my $category  = $arg_ref->{'log4p_category'};
    ##! 64: 'category: ' . $category
    my $loglevel  = $arg_ref->{'log4p_level'};
    ##! 64: 'loglevel: ' . $loglevel
    my $message = $arg_ref->{'message'};
    if (ref $message eq 'ARRAY') {
        $message = shift @{$message};
    }

    ##! 64: 'message: ' . $message

    if ($occupied) {
        warn "Recursive call to log()\nLog message was: $category.$loglevel $message\n";
        return;
    }
    $occupied = 1;

    my $timestamp;
    if ($self->{microseconds}) {
        use Time::HiRes qw( gettimeofday );
        my ($seconds, $micro) = gettimeofday();
        $timestamp = $seconds + $micro/1000000;
    } else {
        $timestamp = time();
    }

    my $loglevel_int = 0;
    if ( exists $LOGLEVELS{$loglevel} ) {
        $loglevel_int = $LOGLEVELS{$loglevel};
    }

    eval {
        my $wf_id = Log::Log4perl::MDC->get('wfid') || 0;
        CTX('dbi')->insert(
            into => $self->{table},
            values  => {
                $self->{table}.'_id' => AUTO_ID,
                logtimestamp       => $timestamp,
                workflow_id        => $wf_id,
                priority           => $loglevel_int,
                category           => $category,
                message            => $message,
            },
        );
    };
    if ($EVAL_ERROR) {
        warn "Error writing log message to database: $EVAL_ERROR\nLog message was: $timestamp $category.$loglevel $message\n";
        $occupied = 0;
        return;
    }

    ##! 1: 'end'
    $occupied = 0;
    return 1;
}

1;

__END__;


=head1 Name

OpenXPKI::Server::Log::Appender::Database

=head1 Description

This class implements an appender for Log4perl that writes messages to
the database. It uses the internal DBI layer and runs inside the
transaction model, so messages are only persisted when the "outer" layer
properly commits the transaction.

Opposite to the default DBI Appender, the table layout is fixed and you
can only control the layout of the message that is written.

In the default setup, this class is used to write the "Technical Log"
for the workflow views but you can use it for any other purpose, too.

=head1 Configuration

=head2 Log4perl Basic Config

The minimal configuration requires only the layout class, the default
layout is to log the message only:

log4perl.appender.Application         = OpenXPKI::Server::Log::Appender::Database
log4perl.appender.Application.layout = Log::Log4perl::Layout::PatternLayout

Additional layout specifications can be given, depending on the used layout
class.

=head2 Log4perl Optional Parameters

=over

=item log4perl.appender.Application.table = application_log

The name of the table to write the data too. This also implies the name
of the primary key column as "<table>_id" and the name of the sequence
"seq_<table>".

=item log4perl.appender.Application.microseconds = 1

Weather to have microseconds in the timestamp, default is yes.
This option requries the Time::HiRes module to be installed.

=back

=head1 Database

=head2 Schema

    CREATE TABLE IF NOT EXISTS `application_log` (
      `application_log_id` bigint(20) unsigned NOT NULL,
      `logtimestamp` decimal(20,6) DEFAULT NULL,
      `workflow_id` decimal(49,0) NOT NULL,
      `priority` int(3) DEFAULT '999',
      `category` varchar(255) NOT NULL,
      `message` longtext
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

=head2 Fields

=over

=item application_log_id

Primary key based on seqeuence (you need to create a corresponding sequence
or a sequence emulation table), see the default schema for your DBI.

=item logtimestamp

timestamp of the event as epoch, microseconds are appended as fraction.
Note that this format has changed with v1.18 and you must adjust your
database to use the new format!

=item workflow_id

The id of the currently running worklow, 0 if no workflow was active.

=item priority

Log priority, stored as integer as defined in Log::Log4perl::Level

=item category

facility/category of the logger used

=item message

The actual log message, after processing by the given layout pattern.

=back
