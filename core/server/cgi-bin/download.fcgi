#!/usr/bin/perl -w

# This script is intended to server as download helper for public access
# it will serve certificates in pem or der format for a given identifier
# The config from the webui wrapper is used to get the name of the socket
# file, the logger config, language settings and realm config. The realm
# is only required to run the login, the script does not do any realm or
# other access checks on the requested items.

use CGI;
use CGI::Fast;
use CGI::Carp qw (fatalsToBrowser);
use English;
use strict;
use warnings;
use Data::Dumper;
use Config::Std;
use OpenXPKI::Log4perl;
use OpenXPKI::Client::Simple;

my $configfile = '/etc/openxpki/webui/default.conf';

# check for explicit file in env, for fcgi
# FcgidInitialEnv FcgidInitialEnv /etc/openxpki/<inst>/webui/default.conf
#
if ($ENV{OPENXPKI_WEBUI_CLIENT_CONF_FILE}
    && -f $ENV{OPENXPKI_WEBUI_CLIENT_CONF_FILE}) {
    $configfile = $ENV{OPENXPKI_WEBUI_CLIENT_CONF_FILE};
}

read_config $configfile => my %config;

OpenXPKI::Log4perl->init_or_fallback( $config{global}{log_config} );
my $log = Log::Log4perl->get_logger();

if (!$config{global}{socket}) {
    $config{global}{socket} = '/var/openxpki/openxpki.socket';
}
if (!$config{global}{scripturl}) {
    $config{global}{scripturl} = '/cgi-bin/webui.fcgi';
}

$log->info('Start fcgi loop ' . $$. ', config: ' . $configfile);

# Set the path to the directory component of the script, this
# automagically creates seperate cookies for path based realms

while (my $cgi = CGI::Fast->new()) {

    my $pki_realm;
    my $result;

    if ($config{global}{realm_mode} eq "path") {

        my $script_path = $ENV{'REQUEST_URI'};
        # Strip off cgi-bin, last word of the path and discard query string
        $script_path =~ s|\/(f?cgi-bin\/)?([^\/]+)((\?.*)?)$||;

        $log->debug('script path is ' . $script_path);

        # if the session has no realm set, try to get a realm from the map

        # We use the last part of the script name for the realm
        if ($script_path =~ qq|\/([^\/]+)\$|) {
            my $script_realm = $1;
            if (!$config{realm}{$script_realm}) {
                $log->fatal('No realm for ident: ' . $script_realm );
                die "Url based realm requested but no realm found for $script_realm!";
            }
            $log->debug('detected realm is ' . $config{realm}{$script_realm});
            $pki_realm = $config{realm}{$script_realm};
        } else {
            # Fall back - only valid with single realm config!
            my @realms = keys %{$config{realm}};
            $pki_realm = shift @realms;
        }

        $log->debug('Path to realm: ' . $pki_realm );

    } elsif ($config{global}{realm_mode} eq "fixed") {
        # Fixed realm mode, mode must be defined in the config
        $pki_realm = $config{global}{realm};
    }

    eval {

        my $cert_identifier = $cgi->param('cert_identifier');

        if (!$cert_identifier) {
            $log->error('No cert_identifier given');
            die "No cert_identifier given";
        }

        my $opts = {
            logger => $log,
            config => {
                socket => $config{global}{socket},
                realm => $pki_realm
            }
        };

        if ($config{auth} && (ref $config{auth} eq 'HASH')) {
            $opts->{auth} = $config{auth};
        }

        my $client = OpenXPKI::Client::Simple->new( $opts );

        $log->debug('Looking for certificate ' . $cert_identifier );

        my $cert_format = uc($cgi->param('format')) || '';
        my $ext;
        if ($cert_format eq 'DER') {
            $ext = '.cer';
        } else {
            $cert_format = 'PEM';
            $ext = '.crt';
        }

        my $cert = $client->run_command('get_cert', {  IDENTIFIER => $cert_identifier, FORMAT => $cert_format });

        my $cert_info = $client->run_command ( "get_cert", {'IDENTIFIER' => $cert_identifier, 'FORMAT' => 'HASH' });
        my $filename = $cert_info->{BODY}->{SUBJECT_HASH}->{CN}->[0] || $cert_info->{BODY}->{IDENTIFIER};

        if (!$cert || !$filename) {
            die "Unable to get cert data";
        }

        print $cgi->header( -type => 'application/octet-string', -expires => "1m", -attachment => $filename.$ext );
        print $cert;
    };

    if (my $eval_err = $EVAL_ERROR) {
        $log->error('Got error from backend ' . $eval_err );

        print $cgi->header(-status => 404),
            $cgi->start_html('Requested entity not found'),
            $cgi->h1('Requested entity not found'),
            $cgi->end_html;
    }

}

$log->info('end fcgi loop ' . $$);


