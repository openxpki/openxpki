#!/usr/bin/env perl

use CGI;
use CGI::Fast;
use CGI::Session;
use JSON;
use English;
use warnings;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use OpenXPKI::i18n qw( i18nGettext set_language set_locale_prefix);
use OpenXPKI::Client::UI;

Log::Log4perl->init('/etc/openxpki/webui/log.conf');

# i18n
set_locale_prefix ('/usr/share/locale');
set_language      ('en_US');

my $log = Log::Log4perl->get_logger();

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
            config => { socket => '/var/openxpki/openxpki.socket' }
        });
        $result = $client->handle_request({ cgi => $cgi });
        $log->debug('request handled');
        $log->trace( Dumper $result );
    };

    print $cgi->header( -cookie=> $cgi->cookie(CGISESSID => $session_front->id), -type => 'application/json' );

    my $json = new JSON();
    if (ref $result eq 'HASH') {

        if ($result->{_raw}) {
            print $json->encode($result->{_raw});
        } else {
            $result->{session_id} = $session_front->id;
            print $json->encode($result);
        }

        $log->debug('got valid result');
        $log->trace( Dumper $result );
    } else {

        if ($EVAL_ERROR) {
            $log->error('eval error during handle' );
            $log->trace($EVAL_ERROR);
            print $json->encode( { status => { 'level' => 'error', 'message' => i18nGettext($EVAL_ERROR) } });
        } else {
            $log->error('uncaught application error');
            print $json->encode( { status => { 'level' => 'error', 'message' => i18nGettext('I18N_OPENXPKI_UI_APPLICATION_ERROR') } });
        }

        $log->trace('result was ' . Dumper $result);
    }

}

$log->info('end fcgi loop ' . $$);