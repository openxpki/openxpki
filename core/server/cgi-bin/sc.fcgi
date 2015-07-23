#!/usr/bin/perl -w

# Wrapper for the Smarcard Frontend Handler

use CGI;
use CGI::Fast;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use English;
use strict;
use warnings;
use Data::Dumper;
use Config::Std;
use Log::Log4perl qw(:easy);
use OpenXPKI::i18n qw( i18nGettext set_language set_locale_prefix );
use OpenXPKI::Client::SC;


my $configfile = '/etc/openxpki/sc/default.conf';

# check for explicit file in env
if ($ENV{OPENXPKI_SC_CLIENT_CONF_FILE}
    && -f $ENV{OPENXPKI_SC_CLIENT_CONF_FILE}) {
    $configfile = $ENV{OPENXPKI_SC_CLIENT_CONF_FILE};
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

if (!$config{global}{socket}) {
    $config{global}{socket} = '/var/openxpki/openxpki.socket';
} 

my %card_config = %config;
delete $card_config{realm};

my @header_tpl;
foreach my $key (keys ($config{header} || {})) {
    my $val = $config{header}{$key};
    $key =~ s/-/_/g;
    push @header_tpl, ("-$key", $val);
}

$log->info('Start fcgi loop ' . $$. ', config: ' . $configfile);

while (my $cgi = CGI::Fast->new()) {

    my $sess_id = $cgi->cookie('oxisess-sc') || undef;
    my $session_front = new CGI::Session(undef, $sess_id, {Directory=>'/tmp'});
    $log->debug('session id (front) is '. $session_front->id);
    
    our $cookie = { 
        -name => 'oxisess-sc', 
        -value => $session_front->id, 
        -Secure => ($ENV{'HTTPS'} ? 1 : 0),
        -HttpOnly => 1 
    };
    our @header = @header_tpl;    
    push @header, ('-cookie', $cgi->cookie( $cookie ));
    push @header, ('-type','application/json; charset=UTF-8');        
  
    my $client = OpenXPKI::Client::SC->new({
        session => $session_front,
        logger => $log,
        config => $config{global},
        card_config => \%card_config,
        auth => $config{auth}
    });
    
    my $result = $client->handle_request({ cgi => $cgi });
    if ($result) {
        $result->render();
    }
    
 
}

$log->info('end fcgi loop ' . $$);
