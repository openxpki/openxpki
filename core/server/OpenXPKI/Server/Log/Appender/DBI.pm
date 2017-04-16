package OpenXPKI::Server::Log::Appender::DBI;

use strict;
use warnings;

# Core modules
use Data::Dumper;
use English;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # we must import "auto_id"

sub new {
    ##! 1: 'start'
    my($proto, %p) = @_;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;
    ##! 1: 'end'
    return $self;
}

sub log {
    ##! 1:  'start'
    my $self    = shift;
    my $arg_ref = { @_ };

    ##! 128: 'arg_ref: ' . Dumper $arg_ref

    my $timestamp = $self->__get_current_utc_time();
    ##! 64: 'timestamp: ' . $timestamp
    my $category  = $arg_ref->{'log4p_category'};
    ##! 64: 'category: ' . $category
    my $loglevel  = $arg_ref->{'log4p_level'};
    ##! 64: 'loglevel: ' . $loglevel
    my $message   = $arg_ref->{'message'}->[0];
    ##! 64: 'message: ' . $message

    my $dbi;

    eval {
        $dbi = CTX('dbi_log');
    };
    if ($EVAL_ERROR || ! defined $dbi) {
        ##! 16: 'dbi_log unavailable!'
        print STDERR "dbi_log unavailable! (tried to log: $timestamp, $category, $loglevel, $message)\n";
        return;
    }

    # TODO: If category IS '*.audit', write to the audittrail. Otherwise,
    #       write to application_log and also put workflow_id into its
    #       own column instead of in the message.
    if ( $category =~ m{\.audit$} ) {
        # do NOT catch DBI errors here as we want to fail if audit
        # is not working
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
    } else {
        $dbi->insert(
            into => 'application_log',
            values  => {
                application_log_id => AUTO_ID,
                logtimestamp       => $timestamp,
                workflow_id        => OpenXPKI::Server::Context::hascontext('workflow_id') ? CTX('workflow_id') : 0,
                priority           => $loglevel,
                category           => $category,
                message            => $message,
            },
        );
    }

    ##! 1: 'end'
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

=head1 Name

OpenXPKI::Server::Log::Appender::DBI

=head1 Description

This is a special log appender for Log::Log4perl. It uses the dbi_log
handle generated during server init to write to the audittrail and
application_log tables.


