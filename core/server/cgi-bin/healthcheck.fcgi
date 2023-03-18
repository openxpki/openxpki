#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Fast;
use CGI::Carp qw (fatalsToBrowser);

use English;
use JSON;
use OpenXPKI::Client;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($FATAL);

my $client;
my @allowed_methods;

# do NOT expose this unless you are in a test environment
# set directly from here, e.g. for testing
# push @allowed_methods ,'showenv';
# set from ENV via apache
@allowed_methods = split /\W+/, $ENV{OPENXPKI_HEALTHCHECK} if ($ENV{OPENXPKI_HEALTHCHECK});

my $socketfile = $ENV{OPENXPKI_CLIENT_SOCKETFILE} || '/var/openxpki/openxpki.socket';

sub __client {
    if (!$client) {
        eval{
            $client = OpenXPKI::Client->new({
                SOCKETFILE => $socketfile,
            });
            $client->init_session();
            DEBUG("Got new client: " . $client->session_id());
        };
        ERROR("Unable to bootstrap client: $EVAL_ERROR") if ($EVAL_ERROR);
    }
    return $client;
}

sub ping {
    my $cgi = shift;

    # if client is not set try to bootstrap it
    $client ||= __client();
    if (!$client || !$client->is_connected()) {
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => 500 );
        print encode_json({ ping => 0 });
        $client = undef;
        ERROR("ping failed");
    } else {
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => 200 );
        print encode_json({ ping => 1 });
        TRACE("ping ok");
    }
}

my %dispatch = (
    showenv => sub {
        my $cgi = shift;
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => 200 );
        print JSON->new->pretty->encode( \%ENV );
    }
);

DEBUG("Start healtcheck pid $$");
while (my $cgi = CGI::Fast->new()) {

    $ENV{REQUEST_URI} =~ m{healthcheck/(\w+)};
    my $method = $1 || 'ping';

    if ($method eq 'ping') {
        ping($cgi);
        next;
    }

    if ( grep { m{\A$method\z} } @allowed_methods ) {
        $dispatch{$method}($cgi);
        next;
    }

    print $cgi->header( -type => 'text/plain', charset => 'utf8', -status => 404 );
    print "Method unsupported or not allowed\n";

}

DEBUG("Healtcheck terminated pid $$");
$client->close_connection() if ($client);