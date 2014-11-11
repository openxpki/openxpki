#!/usr/bin/env perl

use CGI;
use CGI::Fast;
use CGI::Session;
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

# i18n
set_locale_prefix ('/usr/share/locale');
set_language      ('en_US');

my $log = Log::Log4perl->get_logger();

if (!$config{global}{socket}) {
    $config{global}{socket} = '/var/openxpki/openxpki.socket';
}
if (!$config{global}{scripturl}) {
    $config{global}{scripturl} = '/cgi-bin/webui.cgi';
}

$log->info('Start fcgi loop ' . $$);

while (my $cgi = CGI::Fast->new()) {

    $log->debug('check for cgi session');

    my $session_front = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

    $log->debug('session id (front) is '. $session_front->id);

    my $result;
    eval {
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
            print $cgi->header( -cookie=> $cgi->cookie(CGISESSID => $session_front->id), -type => 'application/json' );
            print $json->encode( { status => { 'level' => 'error', 'message' => $error } });
        } else {
            print $cgi->header( -cookie=> $cgi->cookie(CGISESSID => $session_front->id), -type => 'text/html' );
            print $cgi->start_html( -title => $error );
            print "<h1>An error occured</h1><p>$error</p>";
            print $cgi->end_html;
        }
        $log->trace('result was ' . Dumper $result);
    }

}

$log->info('end fcgi loop ' . $$);
