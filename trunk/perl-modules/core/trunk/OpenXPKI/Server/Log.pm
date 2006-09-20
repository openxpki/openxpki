## OpenXPKI::Server::Log.pm 
##
## Written by Michael Bell for the OpenCA project 2004
## Migrated to the OpenXPKI Project 2005
## Copyright transfered from Michael Bell to The OpenXPKI Project in 2005
## (C) Copyright 2004-2006 by The OpenXPKI Project
## $Revision$

package OpenXPKI::Server::Log;

use strict;
use warnings;
use English;

use Log::Log4perl;
use Log::Log4perl::Level;
use OpenXPKI::Exception;
use OpenXPKI::Server::Log::Appender::DBI;

# cache for package filenames (truncate log entries)
my %filename_of_package;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };

    ## load config
    $self->{configfile} = $keys->{CONFIG};

    if (not $self->{configfile})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_LOG_NEW_NO_CONFIGFILE");
    }

    ## scan the configuration all 10 seconds
    ## $self->{log4perl} = Log::Log4perl::init_and_watch($self->{configfile}, 10);
    $self->{log4perl} = Log::Log4perl::init($self->{configfile});
    if (not  $self->{log4perl})
    {
        ## FIXME: we should display here an error message from Log4perl
        ## FIXME: how we can get the error from Log4perl
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_LOG_NEW_LOG4PERL_INIT_FAILED");
    }

    ## ensure that all relevant loggers are present
    foreach my $facility ("auth", "audit", "monitor", "system")
    {
        ## get the relevant logger
        $self->{$facility} = Log::Log4perl->get_logger("openxpki.$facility");
        if (not $self->{$facility})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_LOG_NEW_MISSING_LOGGER",
                params  => {"FACILITY" => $facility});
        }
        ## FIXME: we should check for a wrong DBI config here too
    }

    return $self;
}

sub log
{
    my $self = shift;
    my $keys = { @_ };

    ## FIXME: "undefined message" is inacceptable as log message
    ## FIXME: errors must cause an exception after logging
    ## FIXME: errors are fatal for the logging system

    my ($facility, $prio, $msg) =
       ("monitor", "FATAL", "EMPTY LOG MESSAGE WAS USED!");

    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);

    ## get parameters

    $facility = lc($keys->{FACILITY})
        if (exists $keys->{FACILITY} and
            $keys->{FACILITY} =~ m{ \A (?:auth|audit|monitor|system) \z }xms);

    $prio = uc($keys->{PRIORITY})
        if (exists $keys->{PRIORITY} and
            $keys->{PRIORITY} =~ m{ \A (?:debug|info|warn|error|fatal) \z }xms);

    if (exists $keys->{MESSAGE} and length ($keys->{MESSAGE}))
    {
        $package  = $keys->{MODULE}   if (exists $keys->{MODULE});
        $filename = $keys->{FILENAME} if (exists $keys->{FILENAME});
        $line     = $keys->{LINE}     if (exists $keys->{LINE});
        $msg      = $keys->{MESSAGE};
    }

    # only write the full filename for this module once (don't clobber log
    # with the same filename over and over again)
    if (exists $filename_of_package{$package} && ($filename_of_package{$package} eq $filename)) {
	$filename = undef;
    } else {
	# write out the full file name this time, but remember it for the
	# next message
	$filename_of_package{$package} = $filename;
    }

    ## build and store message
    $msg = "[$package (" . (defined $filename ? $filename . ':' : '') . "$line)] $msg";

    # remove trailing newline characters
    {
	local $INPUT_RECORD_SEPARATOR = '';
	chomp $msg;    
    }

    ## get an ID for the message

    my $return = $self->{$facility}->log (eval ("\$${prio}"), $msg);

    return $return if (exists $keys->{MESSAGE} and length ($keys->{MESSAGE}));

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_SERVER_LOG_EMPTY_LOG_MESSAGE",
        params  => {"PACKAGE"  => $package,
                    "FILENAME" => $filename,
                    "LINE"     => $line});
}

1;
__END__

=head1 Name

OpenXPKI::Server::Log - logging implementation for OpenXPKI

=head1 Description

This is the logging layer of OpenXPKI. Mainly we use Log::Log4perl.
The important difference is that we replace the original DBI appender
with our own appender which can handle some funny details of some
special databases. Additionally our log function do some special
things to meet our requirements.

=head1 Functions

=head2 new

This function only accepts one parameter - C<CONFIG>.
C<CONFIG> includes the filename of the Log::Log4perl configuration.

=head2 log

This function creates a new log message it accept the following
parameters:

=over

=item * PRIORITY (debug, info, warn, error, fatal)

=item * FACILITY (auth, audit, monitor, system)

=item * MESSAGE (normal text string)

=item * MODULE (overwrites the internally determined caller) - optional

=item * FILENAME (overwrites the internally determined caller) - optional

=item * LINE (overwrites the internally determined caller - optional)

=back

Default is C<system.fatal: [OpenXPKI] undefined message>.

