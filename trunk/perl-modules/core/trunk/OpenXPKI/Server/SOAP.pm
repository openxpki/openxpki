#!/usr/bin/perl
#
# SOAP server for mod_perl implementing the Revocation Interface as documented
# in "Deutsche Bank Project Smartcard Badge - PKI Interfaces", version 2.1
#
# 2010-02-12 Martin Bartosch <m.bartosch@cynops.de>
#
# 2011-10-14 Oliver Welter <oliver.welter@leitwelt.com>
#
# 2011-12-01 Scott Hardin <scott@hnsc.de>
#
# CONFIGURATION:
#
# The configuration uses the OpenXPKI config file for notifications
# found in /etc/openxpki/instances/level2/notification.xml.
#
# For the connection to the RT backend, the entry <notifier id="rt">
# is used. The queue name and list of authorized services (from the SN)
# are extrapolated based on the RT username. This is ugly, but it saves
# us from corrupting our notification.xml or creating yet another
# config file. Besides, this interface should evaporate in about 12
# months.
#
# IMPORTANT: I had trouble getting this thing to throw a decent error
# message when the RT queue is wrong. It didn't work. If the script dies
# without any messages, check that the configuration settings (queue name,
# user, password, etc.) are correct.

use strict;
use warnings;

package OpenXPKI::Server::SOAP::Custom::DeuBa::SCB::BadgeOffice;

use Error qw(:try);
use RT::Client::REST;
use RT::Client::REST::Ticket;
use XML::Simple;

## CONFIG

my $debug = 0;
my $cfg = XMLin('/etc/openxpki/instances/level2/notification.xml');

# This is the ACL - the service name in the client CN
# must be one of these entries.
my %allowed_services = map { $_, 1 } qw( pki-soap unit-test-tls-client soap-auth );

# 20120524 Martin Bartosch - FIXME: client authentication disabled for now
$allowed_services{''} = 1;

my ( $rt_queue, $rt_server, $rt_user, $rt_pass, $rt_timeout );
my $backend;

if (    ( ref( $cfg->{notifier} ) eq 'HASH' )
    and ( ref( $cfg->{notifier}->{notification_backend} )  eq 'HASH' )
    and ( $cfg->{notifier}->{notification_backend}->{type} eq 'RT' ) )
{
    $backend = 'RT';

    $rt_queue = 'PKI UAT User';

    $rt_server = $cfg->{notifier}->{notification_backend}->{url}
      || 'https://rt.gto.intranet.db.com/';
    $rt_user = $cfg->{notifier}->{notification_backend}->{username}
      || 'pki-uat';
    $rt_pass = $cfg->{notifier}->{notification_backend}->{password}
      || 'password';
    $rt_timeout = $cfg->{notifier}->{notification_backend}->{timeout}
      || 20;

    # This is a terrible hack for determining which queue to use. I could
    # have put this in the XML, but I didn't want any negative side-effects
    # with other programs using that file...

    if ( $rt_user ne 'pki-uat' ) {
        $rt_queue = 'PKI Prod User';
        %allowed_services = map { $_, 1 } qw( PKI-Gateway );
    }
}
else {
    $backend = 'STDERR';
}

# Adjust path to binary!
sub RevokeSmartcard {
    my $class = shift;
    my $arg   = shift;
    my $reqid = shift || '<not defined>';

    my ( $scb_type, $scb_serial ) = ( split( /_/, $arg ) );

    warn "SOAP: Entered RevokeSmartcard - ",
#      "RT Server: $rt_server, ",
#      "RT User: $rt_user, ",
#      "RT Queue: $rt_queue, ",
      "Token: $arg, ",
      "SCB Type: $scb_type, ",
      "SCB Serial: $scb_serial, ",
      "Request ID: $reqid, ",
      "DN Services: ",
      join( ', ', sort keys %allowed_services ), "\n" if $debug;

    # check if the smartcard type is supported
    if (
        $scb_type !~ m{ \A (?: rsa2 | rsa3 | gd31 | gem2 | certgate1 ) \z }xms )
    {
        $@ = "SOAP CardRevoke reqid=$reqid: Smartcard type ($scb_type) not supported";
        warn $@, "\n";
        return 1;
    }
    my $r  = Apache2::RequestUtil->request();
    my $c  = $r->connection;
    my $dn = 'nossl';
    $dn = $c->ssl_var_lookup('SSL_CLIENT_S_DN') if ( $c->is_https );
    my $service = '';
    if ( $dn =~ m/^[^:]*:(.*)$/ ) {
        $service = $1;
    }

    if ( exists $allowed_services{$service} ) {
        my $rt_subject = 'Token ' . $arg . ' - Certificate Revokation Request';

        my $rt_text = <<"EOM";
A SOAP request to revoke certificates has been received. Please confirm
the validity and then revoke all certificates associated with the following
token:

	'$arg'

The DN of the client making the request is:

	'$dn'

Please consult the system documentation for more details on
determining which certificates are associated with the given
token.

With best regards,

Your PKI-System
	
[Request ID: $reqid]
EOM

        if ( $backend eq 'RT' ) {
            my $rt = RT::Client::REST->new(
                server  => $rt_server,
                timeout => $rt_timeout,
            );

            try {
                $rt->login(
                    username => $rt_user,
                    password => $rt_pass
                );
            }
            catch Exception::Class::Base with {
                warn "SOAP CardRevoke reqid=$reqid: error logging in to RT: ", shift->message;
                return 1;
            };

            my $ticket;

            try {
                $ticket = RT::Client::REST::Ticket->new(
                    rt      => $rt,
                    queue   => $rt_queue,
                    subject => $rt_subject,
                );
            }
            catch Exception::Class::Base with {
                warn
                  "SOAP CardRevoke reqid=$reqid: Error creating RT ticket in queue '$rt_queue': $@\n";
                return 1;
            };

            if ( not $ticket->store( text => $rt_text ) ) {
                warn "SOAP CardRevoke reqid=$reqid: Error storing RT ticket: $@\n";
                return 1;
            }
            warn "SOAP CardRevoke reqid=$reqid: Created RT ticket ", $ticket->id, " for token $arg\n";
            return 0;
        }
        else {
            warn "SOAP CardRevoke reqid=$reqid: OK token:$arg\n";
            return 0;
        }

    }
    else {
        warn "SOAP CardRevoke reqid=$reqid: Error - access denied for '$dn' (service=$service, token=$arg)";
        return 1;
    }
}

sub true {
    my $self = shift;
    warn "Entered 'true'";
    return 1;
}

sub false {
    my $self = shift;
    return 0;
}

sub echo {
    my $self = shift;
    return shift @_;
}

package OpenXPKI::Server::SOAP;

use SOAP::Transport::HTTP;

#use SOAP::Transport::HTTP2; # Please adjust contructor call below, if you switch this!

use Apache2::ModSSL;

sub handler {

    #warn "Entered OpenXPKI::Server::SOAP::handler";
    my $oSoapHandler = SOAP::Transport::HTTP::Apache->dispatch_to(
        'OpenXPKI::Server::SOAP::Custom::DeuBa::SCB::BadgeOffice')->handle;
}

1;
