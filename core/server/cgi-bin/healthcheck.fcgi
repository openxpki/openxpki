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

Log::Log4perl->easy_init($ERROR);

my $client;
my $json = new JSON();

my $socketfile = $ENV{OPENXPKI_CLIENT_SOCKETFILE} || '/var/openxpki/openxpki.socket';

while (my $cgi = CGI::Fast->new()) {

    if (!$client) {
        eval{
            $client = OpenXPKI::Client->new({
                SOCKETFILE => $socketfile,
            });
            $client->init_session();
        };
    }

    if (!$client || !$client->is_connected()) {
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => 500 );
        print $json->encode({ ping => 0 });
        $client = undef;
    } else {
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => 200 );
        print $json->encode({ ping => 1 });
    }
}

$client->close_connection() if ($client);