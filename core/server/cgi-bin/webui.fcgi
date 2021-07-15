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
use JSON;
use English;
use strict;
use warnings;
use Data::Dumper;
use Config::Std;
use OpenXPKI::Log4perl;
use Log::Log4perl::MDC;
use MIME::Base64 qw( encode_base64 decode_base64 );
use Digest::SHA;
use Crypt::CBC;
use OpenXPKI::i18n qw( i18nGettext i18nTokenizer set_language set_locale_prefix);
use OpenXPKI::Client;
use OpenXPKI::Client::Config;
use OpenXPKI::Client::UI;
use OpenXPKI::Client::UI::Request;

my $conf;
my $log;
my $json = new JSON();

eval {
    my $config = OpenXPKI::Client::Config->new('webui');
    $log = $config->logger();
    # do NOT call config here as webui does not
    # use the URI based  endpoint logic yet
    $conf = $config->default();
    $log->debug(Dumper $conf);# if ($log->is_trace());
};

if (my $err = $EVAL_ERROR) {
    my $cgi = CGI::Fast->new();
    print $cgi->header( -type => 'application/json' );
    print $json->encode( { status => { 'level' => 'error', 'message' => i18nGettext('I18N_OPENXPKI_UI_APPLICATION_ERROR') } });
    die $err;
}

if (!$conf->{global}->{socket}) {
    $conf->{global}->{socket} = '/var/openxpki/openxpki.socket';
}
if (!$conf->{global}->{scripturl}) {
    $conf->{global}->{scripturl} = '/cgi-bin/webui.fcgi';
}

my @header_tpl;
foreach my $key (keys %{$conf->{header}}) {
    my $val = $conf->{header}->{$key};
    $key =~ s/-/_/g;
    push @header_tpl, ("-$key", $val);
}


if ($conf->{global}->{session_path} || defined $conf->{global}->{ip_match} || $conf->{global}->{session_timeout}) {

    if ($conf->{session}) {
        $log->error('Session parameters in [global]  and [session] found! Ignoring [global]');
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

if ($conf->{session}->{driver} && $conf->{session}->{driver} eq 'openxpki') {
    warn "Builtin session driver is deprecated and will be removed with next release!";
    $log->warn("Builtin session driver is deprecated and will be removed with next release!");
}


$log->info('Start fcgi loop ' . $$);

# We persist the client in the CGI *per session*
# Sharing one client with multiple sessions requires some work on detach/
# switching sessions in backend to prevent users from getting wrong sessions!

my $backend_client;

sub __handle_error {

    my $cgi = shift;
    my $error = shift;
    # only echo UI error messages to prevent data leakage
    if (!$error || $error !~ /I18N_OPENXPKI_UI/) {
        $log->info($error || 'undef passed to handle_error');
        $error = i18nGettext('I18N_OPENXPKI_UI_APPLICATION_ERROR');
    } else {
        $error = i18nTokenizer($error);
        $log->info($error);
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

sub __get_cookie_cipher {

    my $key = $conf->{session}->{cookey} || '';
    # a list of ENV variables, added to the cookie passphrase
    # binds the cookie encyption to the system environment
    # Even if the Cryrp::CBC module will run a hash on the passphrase
    # we directly use sha256 here to preprocess the input data one by one
    # to keep the memory footprint as small as possible
    if ($conf->{session}->{fingerprint}) {
        $log->trace('Use fingerprint for cookie encryption: ' . $conf->{session}->{fingerprint});
        my $sha = Digest::SHA->new('sha256');
        $sha->add($key) if ($key);
        map { $sha->add($ENV{$_}) if ($ENV{$_}); } split /\W+/, $conf->{session}->{fingerprint};
        $key = $sha->digest;
        $log->trace(sprintf('Cookie encryption key: %*vx', '', $key)) if ($log->trace);
    }
    return unless ($key);
    my $cipher = Crypt::CBC->new(
        -key => $key,
        -pbkdf => 'opensslv2',
        -cipher => 'Crypt::OpenSSL::AES',
    );
    return $cipher;

}

=head2 encrypt_cookie

The key is read from the config, the cookie value is expected as argument.
Returns the encrypted value, if no key is set, returns the plain input value.

=cut

sub encrypt_cookie {

    my $value = shift;
    return $value unless ($value);

    my $cipher = __get_cookie_cipher();
    return $value unless ($cipher);

    return encode_base64($cipher->encrypt($value));

}

=head2 decrypt_cookie

Reverse to encrypt_cookie

=cut

sub decrypt_cookie {

    my $value = shift;

    return unless($value);

    my $cipher = __get_cookie_cipher();
    return $value unless ($cipher);
    my $plain;
    eval {
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

    Log::Log4perl::MDC->remove();
    Log::Log4perl::MDC->put('sid', $sess_id ? substr($sess_id,0,4) : undef);

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


    my $driver_args = $conf->{session_driver} ? $conf->{session_driver} : { Directory => '/tmp' };
    my $session_front = new CGI::Session($conf->{session}->{driver}, $sess_id, $driver_args );
    Log::Log4perl::MDC->put('sid', substr($session_front->id,0,4));

    if (defined $conf->{session}->{timeout}) {
        $session_front->expire( $conf->{session}->{timeout} );
    }

    our $cookie = {
        -name => 'oxisess-webui',
        -value => encrypt_cookie($session_front->id),
        -SameSite => 'Strict',
        -Secure => ($ENV{'HTTPS'} ? 1 : 0),
        -HttpOnly => 1,
    };

    $log->debug('session id (front) is '. $session_front->id);

    # Set the path to the directory component of the script, this
    # automagically creates seperate cookies for path based realms
    my $realm_mode = $conf->{global}->{realm_mode} || '';
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
                if (!$conf->{realm}->{$script_realm}) {
                    $log->debug('No realm for ident: ' . $script_realm );
                    __handle_error($cgi, 'I18N_OPENXPKI_UI_NO_SUCH_REALM_OR_SERVICE');
                    $session_front->flush();
                    $backend_client->detach();
                    next;
                }
                $log->debug('detected realm is ' . $conf->{realm}->{$script_realm});

                my ($realm, $stack) = split (/;/,$conf->{realm}->{$script_realm});
                $session_front->param('pki_realm', $realm);
                if ($stack) {
                    $session_front->param('auth_stack', $stack);
                    $log->debug('Auto-Select stack based on realm path');
                }
            } else {
                $log->warn('Unable to read realm from url path');
            }
        }
    } elsif ($realm_mode eq "fixed") {
        # Fixed realm mode, mode must be defined in the config
        $session_front->param('pki_realm', $conf->{global}->{realm});
    }

    if ($conf->{login} && $conf->{login}->{stack}) {
        $ENV{OPENXPKI_AUTH_STACK} = $conf->{login}->{stack};
    }

    push @header, ('-cookie', $cgi->cookie( $cookie ));
    push @header, ('-type','application/json; charset=UTF-8');

    $log->trace('Init UI using backend ' . Dumper $backend_client);

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
            logger => $log,
            config => $conf->{global},
            %pkey,
        });

        my $req = OpenXPKI::Client::UI::Request->new( cgi => $cgi, logger => $log );
        $log->trace( Dumper $req ) if ($log->is_trace());
        $result = $client->handle_request( $req );
        $log->debug('request handled');
        $log->trace( Dumper $result ) if ($log->is_trace());
    };

    if (!$result || ref $result !~ /OpenXPKI::Client::UI/) {
        __handle_error($cgi, $EVAL_ERROR);
        $log->trace('result was ' . Dumper $result) if ($log->is_trace());
    }

    # write session changes to backend
    $session_front->flush();
    # Detach session
    $backend_client->detach();

}

$log->info('end fcgi loop ' . $$);

1;

__END__;
