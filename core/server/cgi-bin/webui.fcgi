#!/usr/bin/perl -w

# If you are unable to run under FastCGI, you can use this script unmodified
# as long as you have the FastCGI perl module installed. If you do not have
# this module, you can just replace CGI::Fast->new with CGI->new and remove
# the use CGI::Fast from the modules list.
# In either case, you might need to change the extension of the scripturl in
# the webui config file.
use strict;
use warnings;
use English;

# Core modules
use Data::Dumper;
use MIME::Base64 qw( encode_base64 decode_base64 );
use Digest::SHA;
use Scalar::Util qw( blessed );
use Encode;

# CPAN modules
use CGI 4.08;
use CGI::Fast;
use CGI::Session;
use JSON;
use Config::Std;
use Log::Log4perl::MDC;
use Crypt::CBC;
use Feature::Compat::Try;

# Project modules
use OpenXPKI::Log4perl;
use OpenXPKI::i18n qw( i18nGettext i18nTokenizer set_language set_locale_prefix);
use OpenXPKI::Client;
use OpenXPKI::Client::Config;
use OpenXPKI::Client::UI;
use OpenXPKI::Client::UI::Request;
use OpenXPKI::Client::UI::Response;
use OpenXPKI::Client::UI::SessionCookie;


my $conf;
my $log;
my @header_tpl;
# We persist the client in the CGI *per session*
# Sharing one client with multiple sessions requires some work on detach/
# switching sessions in backend to prevent users from getting wrong sessions!
my $backend_client;


sub __load_config {

    my $cgi = shift;

    my $config = OpenXPKI::Client::Config->new('webui');
    $log = $config->logger();
    # do NOT call config here as webui does not
    # use the URI based  endpoint logic yet
    $conf = $config->default();

    $log->info("Config read, FCGI pid = $$");
    $log->trace(Dumper $conf) if $log->is_trace;

    # set defaults
    $conf->{global}->{socket} ||= '/var/openxpki/openxpki.socket';
    $conf->{global}->{scripturl} ||= '/cgi-bin/webui.fcgi';

    foreach my $key (keys %{$conf->{header}}) {
        my $val = $conf->{header}->{$key};
        $key =~ s/-/_/g;
        push @header_tpl, ("-$key", $val);
    }

    # legacy config compatibility
    if ($conf->{global}->{session_path} || defined $conf->{global}->{ip_match} || $conf->{global}->{session_timeout}) {
        if ($conf->{session}) {
            $log->error('Session parameters found both in [global] and [session] - ignoring [global]');
        } else {
            $log->warn('Session parameters in [global] are deprecated, please use [session]');
            $conf->{session} = {
                'ip_match' => $conf->{global}->{ip_match} || 0,
                'timeout' => $conf->{global}->{session_timeout} || undef,
            };
            $conf->{session_driver} = { Directory => ( $conf->{global}->{session_path} || '/tmp') };
        }
    }

    if ($conf->{session}->{ip_match}) {
       $CGI::Session::IP_MATCH = 1;
    }

    if (($conf->{session}->{driver}//'') eq 'openxpki') {
        warn "Builtin session driver is deprecated and will be removed with next release!";
        $log->warn("Builtin session driver is deprecated and will be removed with next release!");
    }

    return 1;
}

sub __handle_error {

    my $cgi = shift;
    my $error = shift;

    # only echo UI error messages to prevent data leakage
    if (!$error || $error !~ /I18N_OPENXPKI_UI/) {
        my $msg = $error || '__handle_error() was called with undef';
        if ($log) { $log->error($msg) } else { warn "$error\n" }
        $error = i18nGettext('I18N_OPENXPKI_UI_APPLICATION_ERROR');
    } else {
        $error = i18nTokenizer($error);
        if ($log) { $log->info($error) } else { warn "$error\n" }
    }

    if ( $cgi->http('HTTP_X-OPENXPKI-Client') ) {
        print $cgi->header( -type => 'application/json' );
        print encode_json({ status => { 'level' => 'error', 'message' => $error } });
    } else {
        my $error_utf8 = Encode::encode('UTF-8', $error);
        print $cgi->header( -type => 'text/html' );
        print <<"EOF";
<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>$error_utf8</title>
    </head>
    <body>
        <h1>An error occured</h1>
        <p>$error_utf8</p>
    </body>
</html>
EOF
    }
    return;
}

# Returns the Crypt::CBC cipher to use for cookie encryption or undef if no
# session.cookey config entry is defined.
sub __get_cookie_cipher {

    my $key = $conf->{session}->{cookey} || '';
    # Fingerprint: a list of ENV variables, added to the cookie passphrase,
    # binds the cookie encyption to the system environment.
    # Even though Crypt::CBC will run a hash on the passphrase we still use
    # sha256 here to preprocess the input data one by one to keep the memory
    # footprint as small as possible.
    if ($conf->{session}->{fingerprint}) {
        $log->trace('Use fingerprint for cookie encryption: ' . $conf->{session}->{fingerprint});
        my $sha = Digest::SHA->new('sha256');
        $sha->add($key) if $key;
        map { $sha->add($ENV{$_}) if $ENV{$_} } split /\W+/, $conf->{session}->{fingerprint};
        $key = $sha->digest;
        $log->trace(sprintf('Cookie encryption key: %*vx', '', $key)) if $log->trace;
    }
    return unless ($key);
    my $cipher = Crypt::CBC->new(
        -key => $key,
        -pbkdf => 'opensslv2',
        -cipher => 'Crypt::OpenSSL::AES',
    );
    return $cipher;

}

while (my $cgi = CGI::Fast->new) {
    # load config once
    if (not $conf) {
        try {
            __load_config($cgi);
        }
        catch ($err) {
            warn "$err\n";
            __handle_error($cgi, 'I18N_OPENXPKI_UI_APPLICATION_ERROR');
             next; # stop current loop upon error
        }
    }

    $log->debug("Check for CGI session, FCGI pid = $$");

    my $insecure_cookie = $cgi->http('X-OpenXPKI-Ember-HTTP-Proxy') ? 1 : 0;
    $log->debug("Header 'X-OpenXPKI-Ember-HTTP-Proxy' found - creating insecure cookie for HTTP proxy")
      if $insecure_cookie;

    my $cipher = __get_cookie_cipher();
    my $session_cookie = OpenXPKI::Client::UI::SessionCookie->new(
        cgi => $cgi,
        $cipher ? (cipher => $cipher) : (),
        insecure => $insecure_cookie, # flag to skip "secure" option in cookie
    );

    my $sess_id;
    eval { $sess_id = $session_cookie->fetch_id };
    $log->error($EVAL_ERROR) if $EVAL_ERROR;

    Log::Log4perl::MDC->remove();
    Log::Log4perl::MDC->put('sid', $sess_id ? substr($sess_id,0,4) : undef);

    if ($sess_id) {
        $log->debug("Previous frontend session ID read from cookie: $sess_id");
    } else {
        $log->debug("No previous frontend session ID found in cookie (or no cookie)");
    }

    eval {
        if (!$backend_client || !$backend_client->is_connected()) {
            $backend_client = OpenXPKI::Client->new({
                SOCKETFILE => $conf->{global}->{socket}
            });
            $backend_client->send_receive_service_msg('PING');
        }
    };

    if (my $eval_err = $EVAL_ERROR) {
       $log->error('Error creating backend client ' . $eval_err);
       __handle_error($cgi, "I18N_OPENXPKI_UI_BACKEND_UNREACHABLE");
       next;
    }

    # create CGI session
    my $driver_args = $conf->{session_driver} ? $conf->{session_driver} : { Directory => '/tmp' };
    my $session_front = CGI::Session->new($conf->{session}->{driver}, $sess_id, $driver_args );
    $session_front->expire($conf->{session}->{timeout}) if defined $conf->{session}->{timeout};

    $session_cookie->id($session_front->id);
    Log::Log4perl::MDC->put('sid', substr($session_front->id,0,4));

    $log->debug(
        'Frontend session: ID = ' . $session_front->id .
        ($session_front->expire ? ', expiration = ' . $session_front->expire : '')
    );

    my $response = OpenXPKI::Client::UI::Response->new(session_cookie => $session_cookie);
    $response->add_header(@header_tpl);

    # Set the path to the directory component of the script, this
    # automagically creates seperate cookies for path based realms
    my $realm_mode = $conf->{global}->{realm_mode} || 'select';
    my $detected_realm;
    my $realm_path_map; # only for realm_mode = path
    $log->debug("Realm mode = $realm_mode");

    if ($realm_mode eq "path") {
        my $script_path = $ENV{'REQUEST_URI'};

        # Strip off /cgi-bin/xxx?aa=bb ("cgi-bin", last path component, query string)
        $script_path =~ s|\/(f?cgi-bin\/)?([^\/]+)((\?.*)?)$||;
        $response->session_cookie->path($script_path);

        $log->debug("Script path = '$script_path'");

        # We use the last part of the script name for the realm
        my $script_realm;
        if ($script_path =~ qq|\/([^\/]+)\$|) {
            $script_realm = $1;
        } else {
            $log->warn('Unable to read realm from URL path');
        }

        # Prepare realm selection
        if ('index' eq $script_realm) {
            $log->debug('Special path detected - showing realm selection page');

            # Enforce new session to get rid of selected realm etc.
            $session_front->flush();
            $backend_client->detach();

            # Create a map of realms to URL paths:
            # {
            #     realma => [
            #         { url => 'realm-a', stack => 'LocalPassword' },
            #         { url => 'realm-a-cert', stack => 'Certificate' },
            #     ],
            #     realmb => ...
            # }
            my $realm_root_url = $script_path;
            $realm_root_url =~ s{^ ( ( / [^/]+ )*? ) / [^/]* /? $}{$1}msx; # strip off last path component

            for my $url_alias (keys $conf->{realm}->%*) {
                my ($realm, $stack) = split (/\s*;\s*/, $conf->{realm}->{$url_alias});
                $realm_path_map->{$realm} //= [];
                push $realm_path_map->{$realm}->@*, {
                    url => sprintf("%s/%s/", $realm_root_url, $url_alias),
                    stack => $stack,
                }
            };

            $log->trace('URL path and auth stacks by realm: ' . Dumper($realm_path_map)) if $log->is_trace;
        }

        # If the session has no realm set, try to get a realm from the map
        elsif (!$session_front->param('pki_realm')) {
            if (!$conf->{realm}->{$script_realm}) {
                $log->debug('No realm for ident: ' . $script_realm );
                __handle_error($cgi, 'I18N_OPENXPKI_UI_NO_SUCH_REALM_OR_SERVICE');
                $session_front->flush();
                $backend_client->detach();
                next;
            } else {
                $detected_realm = $conf->{realm}->{$script_realm};
            }
        }

    } elsif ($realm_mode eq "hostname") {
        my $host = $ENV{HTTP_HOST};
        $log->trace('Realm map is: ' . Dumper $conf->{realm});
        foreach my $rule (keys %{$conf->{realm}}) {
            next unless ($host =~ qr/\A$rule\z/);
            $log->trace("realm detection match: $host / $rule ");
            $detected_realm = $conf->{realm}->{$rule};
            last;
        }
        $log->warn('Unable to find realm from hostname: ' . $host) unless($detected_realm);

    } elsif ($realm_mode eq "fixed") {
        # Fixed realm mode, mode must be defined in the config
        $detected_realm = $conf->{global}->{realm};
    }

    if ($detected_realm) {
        $log->debug("Detected realm is '$detected_realm'");
        my ($realm, $stack) = split /\s*;\s*/, $detected_realm;
        $session_front->param('pki_realm', $realm);
        if ($stack) {
            $log->debug("Auto-select auth stack '$stack' based on realm detection");
            $session_front->param('auth_stack', $stack);
        }
    }

    if ($conf->{login} && $conf->{login}->{stack}) {
        $ENV{OPENXPKI_AUTH_STACK} = $conf->{login}->{stack};
    }

    $response->add_header(-type => 'application/json; charset=UTF-8');

    $log->trace('Init UI using backend ' . ref $backend_client);

    my $result;
    eval {
        my %pkey;
        if ($conf->{auth}->{'sign.key'}) {
            my $pk = decode_base64($conf->{auth}->{'sign.key'});
            $pkey{auth} = \$pk;
        }

        my $client = OpenXPKI::Client::UI->new({
            backend => $backend_client,
            session => $session_front,
            log => $log,
            socket_path => $conf->{global}->{'socket'},
            script_url => $conf->{global}->{scripturl},
            $conf->{global}->{staticdir} ? (static_dir => $conf->{global}->{staticdir}) : (),
            $conf->{global}->{loginpage} ? (login_page => $conf->{global}->{loginpage}) : (),
            $conf->{global}->{loginurl} ? (login_url => $conf->{global}->{loginurl}) : (),
            resp => $response,
            realm_mode => $realm_mode,
            $realm_path_map ? (realm_path_map => $realm_path_map) : (),
            %pkey,
        });

        my $req = OpenXPKI::Client::UI::Request->new( cgi => $cgi, logger => $log, session => $session_front );
        $log->trace(ref($req).' - '.Dumper({ map { $_ => $req->{$_} } qw( method cache cgi ) }) ) if ($log->is_trace());
        $result = $client->handle_request( $req );
        $result->render; # CGI output
        $log->debug('Finished request handling');
        $log->trace(ref($result).' - '.Dumper({ map { $_ => $result->{$_} } qw( type _page redirect extra _result ) }) ) if $log->is_trace();
    };

    unless (blessed $result and $result->isa('OpenXPKI::Client::UI::Result')) {
        __handle_error($cgi, $EVAL_ERROR);
        $log->trace('Result: ' . Dumper $result) if $log->is_trace();
    }

    # write session changes to backend
    $session_front->flush();
    # Detach session
    $backend_client->detach();

}

$log->info('End fcgi loop ' . $$);

1;

__END__;
