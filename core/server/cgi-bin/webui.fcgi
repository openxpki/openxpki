#!/usr/bin/perl -w

# If you are unable to run under FastCGI, you can use this script unmodified
# as long as you have the FastCGI perl module installed. If you do not have 
# this module, you can just replace CGI::Fast->new with CGI->new and remove
# the use CGI::Fast from the modules list. 
# In either case, you might need to change the extension of the scripturl in
# the webui config file.

use CGI 4.08;
use CGI::Fast;
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
use OpenXPKI::Client;

my $configfile = '/etc/openxpki/webui/default.conf';

# check for explicit file in env, for fcgi
# FcgidInitialEnv FcgidInitialEnv /etc/openxpki/<inst>/webui/default.conf
# 
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

if (!$config{global}{socket}) {
    $config{global}{socket} = '/var/openxpki/openxpki.socket';
}
if (!$config{global}{scripturl}) {
    $config{global}{scripturl} = '/cgi-bin/webui.fcgi';
}

my @header_tpl;
foreach my $key (keys %{$config{header}}) {
    my $val = $config{header}{$key};
    $key =~ s/-/_/g;
    push @header_tpl, ("-$key", $val);
}


if ($config{global}{ip_match}) {
   $CGI::Session::IP_MATCH = 1;
}

$log->info('Start fcgi loop ' . $$. ', config: ' . $configfile);

# We persist the client in the CGI *per session*
# Sharing one client with multiple sessions requires some work on detach/
# switching sessions in backend to prevent users from getting wrong sessions!

my $backend_client;

while (my $cgi = CGI::Fast->new()) {

    $log->debug('check for cgi session, fcgi pid '. $$ );

    if (!$backend_client || !$backend_client->is_connected()) {
        $backend_client = OpenXPKI::Client->new({ 
            SOCKETFILE => $config{'global'}{'socket'}             
        });
    } else {
        # Detach session from shared client, safety hook
        $backend_client->detach();
    }

    my $sess_id = $cgi->cookie('oxisess-webui') || undef;
    my $sess_path = $config{global}{session_path} || '/tmp';
    my $session_front = new CGI::Session(undef, $sess_id, { Directory => $sess_path });
    our $cookie = { 
        -name => 'oxisess-webui', 
        -value => $session_front->id, 
        -Secure => ($ENV{'HTTPS'} ? 1 : 0),
        -HttpOnly => 1 
    };
    
    if (defined $config{global}{session_timeout}) {
        $session_front->expire( $config{global}{session_timeout} );
    }

    $log->debug('session id (front) is '. $session_front->id);

    # Set the path to the directory component of the script, this
    # automagically creates seperate cookies for path based realms
    my $realm_mode = $config{global}{realm_mode} || '';
    if ($realm_mode eq "path") {

        my $script_path = $ENV{'REQUEST_URI'};
        # Strip off cgi-bin, last word of the path and discard query string
        $script_path =~ s|\/(f?cgi-bin\/)?([^\/]+)((\?.*)?)$||;
        $cookie->{path} = $script_path;

        $log->debug('script path is ' . $script_path);

        # if the session has no realm set, try to get a realm from the map
        if (!$session_front->param('pki_realm')) {
            # We use the last part of the script name for the realm
            my $script_realm;
            if ($script_path =~ qq|\/([^\/]+)\$|) {
                $script_realm = $1;                
                if (!$config{realm}{$script_realm}) {
                    $log->fatal('No realm for ident: ' . $script_realm );
                    die "Url based realm requested but no realm found for $script_realm!";
                }
                $log->debug('detected realm is ' . $config{realm}{$script_realm});
            }
            $session_front->param('pki_realm', $config{realm}{$script_realm});
            $log->debug('Path to realm: ' .$config{realm}{$script_realm});
        }
    } elsif ($realm_mode eq "fixed") {
        # Fixed realm mode, mode must be defined in the config
        $session_front->param('pki_realm', $config{global}{realm});
    }   
    
    our @header = @header_tpl;    
    push @header, ('-cookie', $cgi->cookie( $cookie ));
    push @header, ('-type','application/json; charset=UTF-8');        

    my $result;
    eval {
                
        my $client = OpenXPKI::Client::UI->new({
            backend => $backend_client,                   
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

        if ( $cgi->http('HTTP_X-OPENXPKI-Client') ) {
            print $cgi->header( -type => 'application/json' );
            print $json->encode( { status => { 'level' => 'error', 'message' => $error } });
        } else {
            print $cgi->header( -type => 'text/html' );
            print $cgi->start_html( -title => $error );
            print "<h1>An error occured</h1><p>$error</p>";
            print $cgi->end_html;
        }
        $log->trace('result was ' . Dumper $result);
    }
    
    # Detach session 
    $backend_client->detach();

}

$log->info('end fcgi loop ' . $$);
