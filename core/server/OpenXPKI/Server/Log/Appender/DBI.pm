package OpenXPKI::Server::Log::Appender::DBI;

use strict;
use warnings;

=head1 NAME

OpenXPKI::Server::Log::Appender::DBI

=head1 DESCRIPTION

This is a special log appender for Log::Log4perl. It uses the dbi_log
handle generated during server init to write to the audittrail and
application_log tables.

=head1 METHODS

=cut

# Core modules
use Data::Dumper;
use English;

use Log::Log4perl::Level;
use Carp;
# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # we must import "auto_id"

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
    ##! 1: 'start'
    my($proto, %p) = @_;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;
    ##! 1: 'end'
    return $self;
}

=head2 log

Logs the given message to the database.

Doing complex logging like writing to a database bears the danger of a)
recursive calls to log functions and b) repeated calls due to exceptions.

a) To secure calls to C<log()> a class attribute is used that prevents code deeper
down the hierarchy to eventually call the C<log()> function again.

b) Exceptions in the DB layer during the insert of a log message are caught and
a warning is printed instead of letting them bubble up and cause more logging.

=cut
# flag to prevent called functions (DB layer) from eventually calling log() again
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
    my $message   = $arg_ref->{'message'}->[0];
    ##! 64: 'message: ' . $message

    if ($occupied) {
        warn "Recursive call to log()\nLog message was: $category.$loglevel $message\n";
        return;
    }
    $occupied = 1;

    my $timestamp = $self->__get_current_utc_time();
    ##! 64: 'timestamp: ' . $timestamp

    my $dbi;

    eval {
        $dbi = CTX('dbi_log');
    };
    if ($EVAL_ERROR or not defined $dbi) {
        ##! 16: 'dbi_log unavailable!'
        warn "dbi_log unavailable.\nLog message was: $timestamp $category.$loglevel $message\n";
        $occupied = 0;
        return;
    }

    # TODO: If category IS '*.audit', write to the audittrail. Otherwise,
    #       write to application_log and also put workflow_id into its
    #       own column instead of in the message.
    if ( $category =~ m{\.audit$} ) {
        # eval() just to reset $occupied
        eval {
            $dbi->insert(
                into => 'audittrail',
                values  => {
                    audittrail_key => AUTO_ID,
                    logtimestamp   => $timestamp,
                    loglevel       => $loglevel,
                    category       => $category,
                    message        => $message,
                },
            );
        };
        if (my $eval_err = $EVAL_ERROR) {
            $occupied = 0;
            # do NOT catch DBI errors here as we want to fail if audit
            # is not working
            die $eval_err;
        }
    } else {
        # Prevent exceptions in the DB layer from bubbling up and probably
        # causing more logging (into the database)

        my $loglevel_int = 0;
        if ( exists $LOGLEVELS{$loglevel} ) {
            $loglevel_int = $LOGLEVELS{$loglevel};
        }

        eval {
            $dbi->insert(
                into => 'application_log',
                values  => {
                    application_log_id => AUTO_ID,
                    logtimestamp       => $timestamp,
                    workflow_id        => OpenXPKI::Server::Context::hascontext('workflow_id') ? CTX('workflow_id') : 0,
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
    }

    ##! 1: 'end'
    $occupied = 0;
    return 1;
}

sub __get_current_utc_time {
    my $self = shift;

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        gmtime(time);
    $year += 1900;
    $mon++;
    my $time;
    my $microseconds = 0;
    eval { # if Time::HiRes is available, use it to get microseconds
        use Time::HiRes qw( gettimeofday );
        my ($seconds, $micro) = gettimeofday();
        $microseconds = $micro;
    };
    $time = sprintf("%04d%02d%02d%02d%02d%02d%06d", $year, $mon, $mday, $hour, $min, $sec, $microseconds);

    return $time;
}

1;
__END__



