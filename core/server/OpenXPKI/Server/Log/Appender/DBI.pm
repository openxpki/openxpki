## OpenXPKI::Server::Log::Appender::DBI.pm 
##
## Written in 2007 by Alexander Klink for the OpenXPKI Project
## Copyright (C) 2007 by The OpenXPKI Project
package OpenXPKI::Server::Log::Appender::DBI;

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
use English;

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

    my $serial;
    eval {
        $serial = $dbi->get_new_serial(
            TABLE => 'AUDITTRAIL',
        );
        ##! 64: 'serial: ' . $serial
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        ##! 16: 'exception caught'
        if ($exc->message() eq 'I18N_OPENXPKI_SERVER_DBI_DBH_DO_QUERY_NOT_CONNECTED') {
            ##! 16: 'dbi_log not connected'
            print STDERR "dbi_log not connected! (tried to log: $timestamp, $category, $loglevel, $message)\n";
            return; 
        }
        else {
            $exc->rethrow();
        }
    }

    $dbi->insert(
        TABLE => 'AUDITTRAIL',
        HASH  => {
            AUDITTRAIL_SERIAL => $serial,
            TIMESTAMP         => $timestamp,
            CATEGORY          => $category,
            LOGLEVEL           => $loglevel,
            MESSAGE           => $message,
        },    
    );
    $dbi->commit();

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

This is a special log appender for Log::Log4perl. It only implements a
delayed connection setup. We use exactly the way described by the modules
description.

=head1 Functions

=head2 _init

stores the parameters in a variable of the instance for later access.

=head2 create_statement

calls _init of the SUPER class (Log::Log4perl::Appender::DBI) and if
this succeeds then the create_statement of the SUPER class is called. The
_init enforces a delayed connection setup to the database.
