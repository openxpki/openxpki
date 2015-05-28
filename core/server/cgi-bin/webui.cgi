#!/usr/bin/perl -w

use CGI;
use CGI::Session;
use CGI::Carp qw (fatalsToBrowser);
use JSON;
use English;
use strict;
use warnings;
use Data::Dumper;
use Config::Std;
use Log::Log4perl qw(:easy);
use OpenXPKI::i18n qw( i18nGettext set_language set_locale_prefix);
use OpenXPKI::Client::UI;


my $configfile = '/etc/openxpki/webui/default.conf';

# check for explicit file in env
if ($ENV{OPENXPKI_WEBUI_CLIENT_CONF_FILE}
    && -f $ENV{OPENXPKI_WEBUI_CLIENT_CONF_FILE}) {
    $configfile = $ENV{OPENXPKI_WEBUI_CLIENT_CONF_FILE};
}

read_config $configfile => my %config;

if ($config{global}{log_config} && -f $config{global}{log_config}) {
    Log::Log4perl->init( $config{global}{log_config} );
} else {
    Log::Log4perl->easy_init({ level => $DEBUG });
}

my $locale_directory = $config{global}{locale_directory} || '/usr/share/locale';  
my $default_language = $config{global}{default_language} || 'en_US';

set_locale_prefix ($locale_directory);
set_language      ($default_language);

my $log = Log::Log4perl->get_logger();

$log->info('Start single cgi  ' . $$. ', config: ' . $configfile);

my $cgi = CGI->new;

$log->debug('check for cgi session');

my $session_front = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

our $cookie = { -name => 'CGISESSID', -value => $session_front->id };

$log->debug('session id (front) is '. $session_front->id);

if (!$config{global}{socket}) {
    $config{global}{socket} = '/var/openxpki/openxpki.socket';
}
if (!$config{global}{scripturl}) {
    $config{global}{scripturl} = '/cgi-bin/webui.cgi';
}

my $result;
eval {

    # Set the path to the directory component of the script, this
    # automagically creates seperate cookies for path based realms
    if ($config{global}{realm_mode} eq "path") {

        my $script_path = $ENV{'REQUEST_URI'};
        # Strip off last word of the path and discard query string
        $script_path =~ s|\/([^\/]+)((\?.*)?)$||;
        $cookie->{path} = $script_path;

        $log->debug('script path is ' . $script_path);

        # if the session has no realm set, try to get a realm from the map
        if (!$session_front->param('pki_realm')) {
            $script_path =~ qq|\/([^\/]+)\/|;
            my $script_realm = $1;
            if (!$config{realm}{$script_realm}) {
                die "Url based realm requested but no realm found for $script_realm!";
            }
            $session_front->param('pki_realm', $config{realm}{$script_realm});
            $log->debug('Path to realm: ' .$config{realm}{$script_realm});
        }
    } elsif ($config{global}{realm_mode} eq "fixed") {
        # Fixed realm mode, mode must be defined in the config
        $session_front->param('pki_realm', $config{global}{realm});
    }


    my $client = OpenXPKI::Client::UI->new({
        session => $session_front,
        logger => $log,
        config => $config{global}
    });
    $result = $client->handle_request({ cgi => $cgi });
    $log->debug('request handled');
    $log->trace( Dumper $result );
};

if (!$result || ref $result !~ /OpenXPKI::Client::UI/) {
    my $json = new JSON();
    my $error;
    if ($EVAL_ERROR) {
        $log->error('eval error during handle' );
        $log->debug($EVAL_ERROR);
        $error = i18nGettext($EVAL_ERROR);
    } else {
        $log->error('uncaught application error');
        $error = i18nGettext('I18N_OPENXPKI_UI_APPLICATION_ERROR')
    }

    my $accept = $cgi->http('HTTP_ACCEPT');
    my $xreq = $cgi->http('HTTP_X-REQUESTED-WITH');
    if ($accept =~ /json/ || $xreq) {
        print $cgi->header( -cookie=> $cgi->cookie( $cookie ), -type => 'application/json' );
        print $json->encode( { status => { 'level' => 'error', 'message' => $error } });
    } else {
        print $cgi->header( -cookie=> $cgi->cookie( $cookie ), -type => 'text/html' );
        print $cgi->start_html( -title => $error );
        print "<h1>An error occured</h1><p>$error</p>";
        print $cgi->end_html;
    }
    $log->trace('result was ' . Dumper $result);
}
