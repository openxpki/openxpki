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
use OpenXPKI::Log4perl;
use Log::Log4perl::MDC;
use MIME::Base64 qw( encode_base64 decode_base64 );

use OpenXPKI::i18n qw( i18nGettext set_language set_locale_prefix);
use OpenXPKI::Client::UI;
use OpenXPKI::Client;
use OpenXPKI::Client::Session;


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


if ($config{global}{session_path} || defined $config{global}{ip_match} || $config{global}{session_timeout}) {

    if ($config{session}) {
        $log->error('Session parameters in [global]  and [session] found! Ignoring [global]');
    } else {
        $log->warn('Session parameters in [global] are deprecated, please use [session]');
        $config{session} = {
            'ip_match' => $config{global}{ip_match} || 0,
            'timeout' => $config{global}{session_timeout} || undef,
        };
        $config{session_driver} = { Directory => ( $config{global}{session_path} || '/tmp') };
    }
}

if ($config{session}{ip_match}) {
   $CGI::Session::IP_MATCH = 1;
}

$log->info('Start fcgi loop ' . $$. ', config: ' . $configfile);

# We persist the client in the CGI *per session*
# Sharing one client with multiple sessions requires some work on detach/
# switching sessions in backend to prevent users from getting wrong sessions!

my $json = new JSON();
my $backend_client;

sub __handle_error {

    my $cgi = shift;
    my $error = shift;
    if ($error) {
        $log->error('error while handling request');
        $log->debug($error);

        # only echo UI error messages to prevent data leakage
        if ($error !~ /I18N_OPENXPKI_UI/) {
            $error = 'I18N_OPENXPKI_UI_APPLICATION_ERROR';
        }
        $error = i18nGettext($error);
    } else {
        $log->error('uncaught application error');
        $error = 'I18N_OPENXPKI_UI_APPLICATION_ERROR';
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
    return;
}

=head2 encrypt_cookie

The key is read from the config, the cookie value is expected as argument.
Returns the encrypted value, if no key is set, returns the plain input value.

=cut

sub encrypt_cookie {

    my $value = shift;
    my $key = $config{session}{cookey};
    return $value unless ($key && $value);
    my $cipher = Crypt::CBC->new(
        -key => $key,
        -cipher => 'Crypt::OpenSSL::AES',
    );
    return encode_base64($cipher->encrypt($value));

}

=head2 decrypt_cookie

Reverse to encrypt_cookie

=cut

sub decrypt_cookie {

    my $value = shift;
    my $key = $config{session}{cookey};
    return $value unless ($key && $value);
    my $plain;
    eval {
        my $cipher = Crypt::CBC->new(
            -key => $key,
            -cipher => 'Crypt::OpenSSL::AES',
        );
        $plain = $cipher->decrypt(decode_base64($value));
    };
    if (!$plain) {
        $log->error("Unable to decrypt cookie ($EVAL_ERROR)");
    }
    return $plain;

}

while (my $cgi = CGI::Fast->new()) {

    $log->debug('check for cgi session, fcgi pid '. $$ );

    our @header = @header_tpl;

    # TODO - encrypt for protection!
    my $sess_id = $cgi->cookie('oxisess-webui') || undef;

    $sess_id = decrypt_cookie($sess_id);

    my $session_front;

    Log::Log4perl::MDC->put('sid', $sess_id ? substr($sess_id,0,4) : undef);
    Log::Log4perl::MDC->put('ssid', undef);

    eval {
        if (!$backend_client || !$backend_client->is_connected()) {
            $backend_client = OpenXPKI::Client->new({
                SOCKETFILE => $config{'global'}{'socket'}
            });
        }

        # if we use the openxpki internal session handler, we must initialize
        # the backend before we can load the frontend session data
        # If default CGI::Session is used, this is done internally by the UI Client
        if ($config{session}{driver} && $config{session}{driver} eq 'openxpki') {

            $backend_client->init_session({ SESSION_ID => $sess_id, NEW_ON_FAIL => 1 });
            $session_front = OpenXPKI::Client::Session::factory( $backend_client, $log );

            # if a frontend timeout smaller than the backend timeout is set
            # we get the problem that the frontend session gets deleted when
            # reloaded. In this case we generate a new backend session
            if (!$session_front || $session_front->is_expired()) {
                $backend_client->logout();
                $backend_client->init_session();
                $log->debug('frontend session expired - logout backend');
                $session_front = OpenXPKI::Client::Session::factory( $backend_client, $log );
            }

            $sess_id = $backend_client->get_session_id();
            $log->debug('Backend client session id ' . $sess_id );

            Log::Log4perl::MDC->put('sid', substr($sess_id,0,4));
            Log::Log4perl::MDC->put('ssid', substr($sess_id,0,4));
        }
    };

    if (my $eval_err = $EVAL_ERROR) {
       $log->error('Error creating backend client ' . $eval_err);
       __handle_error($cgi, $eval_err);
       next;
    }

    # this creates a standard CGI::Session object if OXI session is not used
    if (!$session_front) {
        my $driver_args = $config{session_driver} ? $config{session_driver} : { Directory => '/tmp' };
        $session_front = new CGI::Session($config{session}{driver}, $sess_id, $driver_args );
        Log::Log4perl::MDC->put('sid', substr($session_front->id,0,4));
    }

    if (defined $config{session}{timeout}) {
        $session_front->expire( $config{session}{timeout} );
    }

    our $cookie = {
        -name => 'oxisess-webui',
        -value => encrypt_cookie($session_front->id),
        -Secure => ($ENV{'HTTPS'} ? 1 : 0),
        -HttpOnly => 1
    };

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

    push @header, ('-cookie', $cgi->cookie( $cookie ));
    push @header, ('-type','application/json; charset=UTF-8');

    $log->trace('Init UI using backend ' . Dumper $backend_client);

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
        __handle_error($cgi, $EVAL_ERROR);
        $log->trace('result was ' . Dumper $result);
    }

    # write session changes to backend
    $session_front->flush();
    # Detach session
    $backend_client->detach();

}

$log->info('end fcgi loop ' . $$);
