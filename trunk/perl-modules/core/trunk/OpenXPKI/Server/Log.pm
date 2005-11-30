## OpenXPKI::Server::Log.pm 
##
## Written by Michael Bell for the OpenCA project 2004
## Migrated to the OpenXPKI Project 2005
## Copyright transfered from Michael Bell to The OpenXPKI Project in 2005
## Copyright (C) 2004-2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Server::Log;

use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use Log::Log4perl;
use Log::Log4perl::Level;
use OpenXPKI::Server::Log::Appender::DBI;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG     => 0,
               };

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
            message => "OPENCA_I18M_LOG_NEW_LOG4PERL_INIT_FAILED");
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
       ("system", "FATAL", "EMPTY LOG MESSAGE WAS USED!");

    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);

    ## get parameters

    $facility = lc($keys->{FACILITY})
        if (exists $keys->{FACILITY} and
            $keys->{FACILITY} =~ /^(auth|audit|monitor|system)$/);

    $prio = uc($keys->{PRIORITY})
        if (exists $keys->{PRIORITY} and
            $keys->{PRIORITY} =~ /^(debug|info|warn|error|fatal)$/);

    if (exists $keys->{MESSAGE} and length ($keys->{MESSAGE}))
    {
        $package  = $keys->{MODULE}   if (exists $keys->{MODULE});
        $filename = $keys->{FILENAME} if (exists $keys->{FILENAME});
        $line     = $keys->{LINE}     if (exists $keys->{LINE});
        $msg      = $keys->{MESSAGE};
    }

    ## build and store message

    $msg = "[$package ($filename:$line)] $msg\n";

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

=head1 Description

This is the logging layer of OpenXPKI. Mainly we use Log::Log4perl.
The important difference is that we replace the original DBI appender
with our own appender which can handle some funny details of some
special databases. Additionally our log function do some special
things to meet our requirements.

=head1 Functions

=head2 new

This function only accepts two parameters - C<DEBUG> and C<CONFIG>.
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

