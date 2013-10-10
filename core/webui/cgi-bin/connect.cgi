#!/usr/bin/perl

use CGI;
use CGI::Session;
use JSON;
use English;
use warnings;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use OpenXPKI::Client::UI;

#Log::Log4perl->init('/etc/openxpki/webui/log.conf');
Log::Log4perl->easy_init({ level => $TRACE, file => '>>/var/openxpki/webui.log' });

my $log = Log::Log4perl->get_logger();

my $cgi = CGI->new;

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
    $result->{session_id} = $session_front->id;   
     
    print $json->encode($result);
    $log->debug('got valid result');
    $log->trace( Dumper $result );
} else {
        
    if ($EVAL_ERROR) {
        $log->error('eval error during handle' );
        $log->trace($EVAL_ERROR);
        print $json->encode( { status => { 'level' => 'error', 'message' => $EVAL_ERROR } });
    } else {
        $log->error('uncaught application error');
        print $json->encode( { status => { 'level' => 'error', 'message' => 'Application error!' } });    
    }
        
    $log->trace('result was ' . Dumper $result);
} 

