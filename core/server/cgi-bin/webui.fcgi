#!/usr/bin/perl -w
use OpenXPKI;

# If you are unable to run under FastCGI, you can use this script unmodified
# as long as you have the FastCGI perl module installed. If you do not have
# this module, you can just replace CGI::Fast->new with CGI->new and remove
# the use CGI::Fast from the modules list.
# In either case, you might need to change the extension of the scripturl in
# the webui config file.

# Core modules
use MIME::Base64 qw( encode_base64 decode_base64 );
use Encode;

# CPAN modules
use CGI 4.08;
use CGI::Fast;
use JSON;
use Config::Std;
use Log::Log4perl::MDC;
use Mojolicious::Controller;

# Project modules
use OpenXPKI::Log4perl;
use OpenXPKI::i18n qw( i18nGettext i18nTokenizer set_language set_locale_prefix);
use OpenXPKI::Client;
use OpenXPKI::Client::Config;
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Client::Service::WebUI;
use OpenXPKI::Client::Service::WebUI::Session;


my $conf;
my $log;
my @header_tpl;
# We persist the client in the CGI *per session*
# Sharing one client with multiple sessions requires some work on detach/
# switching sessions in backend to prevent users from getting wrong sessions!
my $backend_client;

my $config;

=head2 send_response_fcgi

Renders the HTTP response via FCGI.

=cut

# TODO Remove CGI legacy send_response_fcgi()
sub send_response ($cgi, $ui, $response) {

    my $status = '200 OK';

    if ($response->has_error) {
        $status = $response->http_status_line;
        chomp $status;

        if ($ui->request->headers->header('X-OPENXPKI-Client')) {
            print $cgi->header( -type => 'application/json', charset => 'utf8', -status => $status );
            print encode_json({
                status => {
                    level => 'error',
                    message => $response->error_message,
                }
            });
        } else {
            print $cgi->header( -type => 'text/html', charset => 'utf8', -status => $status );
            # my $error = Encode::encode('UTF-8', $response->error_message);
            my $error = $response->error_message;
            print <<"EOF";
<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>$error</title>
    </head>
    <body>
        <h1>An error occured</h1>
        <p>$error</p>
    </body>
</html>
EOF
        }
        return;
    }

    my $page = $response->result;
    my $ui_resp = $page->ui_response;

    # helper to print HTTP headers
    my $print_headers = sub {
        my @headers = $ui->cgi_headers($response->extra_headers)->%*;
        push @headers, -cookie => [ map { $_->to_string } $ui->session_cookie->as_mojo_cookies($ui->session)->@* ];
        print $cgi->header(@headers);
    };

    # File download
    if ($page->has_raw_bytes or $page->has_raw_bytes_callback) {
        $print_headers->();
        # A) raw bytes in memory
        if ($page->has_raw_bytes) {
            $ui->log->debug("Sending raw bytes (in memory)");
            print $page->raw_bytes;
        }
        # B) raw bytes retrieved by callback function
        elsif ($page->has_raw_bytes_callback) {
            $ui->log->debug("Sending raw bytes (via callback)");
            # run callback, passing a printing function as argument
            $page->raw_bytes_callback->(sub { print @_ });
        }

    # Standard JSON response
    } elsif ($ui->request->headers->header('X-OPENXPKI-Client')) {
        $print_headers->();
        $ui->log->debug("Sending JSON response");
        print $ui->ui_response_to_json($ui_resp);

    # Redirects
    } else {
        my $url = '';
        # redirect to given page
        if ($ui_resp->redirect->is_set) {
            $url = $ui_resp->redirect->to;

        # redirect to downloads / page pages
        } elsif (my $body = $ui->ui_response_to_json($ui_resp)) {
            $url = $page->call_persisted_response( { data => $body } );
        }

        $ui->log->debug("Raw redirect target: $url");

        # if url does not start with http or slash, prepend baseurl + route name
        if ($url !~ m{\A http|/}x) {
            my $baseurl = $ui->session->param('baseurl') || $ui->request->param('baseurl');
            $ui->log->debug("Adding baseurl $baseurl");
            $url = sprintf("%s/#/openxpki/%s", $baseurl, $url);
        }
        # HTTP redirect
        $ui->log->debug("Sending HTTP redirect to: $url");
        print $cgi->redirect($url);
    }
}

$config = OpenXPKI::Client::Config->new('webui');
$log = $config->log;
$log->info("UI handler initialized");

$conf = $config->endpoint_config('');

while (my $cgi = CGI::Fast->new("")) {

    $log->debug("FCGI pid = $$");

    my $mojo_req = OpenXPKI::Client::Service::WebUI->cgi_to_mojo_request;

    my $client = OpenXPKI::Client::Service::WebUI->new(
        service_name => 'webui',
        config_obj => $config,
        webserver_env => \%ENV,
        remote_address => $ENV{REMOTE_ADDR},
        request => $mojo_req,
        endpoint => '',
        # OpenXPKI::Client::Service::Role::Base->_build_config() will pass the
        # empty endpoint to OpenXPKI::Client::Config->endpoint_config() which
        # will then load the default() config
    );

    my $session_front;

    my $response = $client->cgi_safe_sub(sub {
        my $session_cookie = $client->session_cookie;
        $session_front = $client->session;

        #
        # Backend (server communication)
        #
        try {
            if (not $backend_client or not $backend_client->is_connected) {
                $backend_client = OpenXPKI::Client->new(
                    socketfile => $conf->{global}->{socket}
                );
                $backend_client->send_receive_service_msg('PING');
            }
        }
        catch ($err) {
            $log->error("Error creating backend client: $err");
            return $client->new_response(503 => 'I18N_OPENXPKI_UI_BACKEND_UNREACHABLE');
        }

        $client->backend($backend_client);

        #
        # Detect realm
        #
        my $detected_realm;

        my $realm_mode = $client->realm_mode;
        $log->debug("Realm mode = $realm_mode");

        # PATH mode
        if ("path" eq $realm_mode) {
            # Set the path to the directory component of the script, this
            # automagically creates seperate cookies for path based realms
            $session_cookie->path($client->url_path->to_string);

            # Interpret last part of the URL path as realm
            my $script_realm = $client->url_path->parts->[-1];
            if ('webui' eq $script_realm) {
                $script_realm = '' ;
                $log->warn('Unable to read realm from URL path');
            }

            # Prepare realm selection
            if ('index' eq $script_realm) {
                $log->debug('Special path detected - showing realm selection page');

                $session_front->flush;
                $backend_client->detach; # enforce new backend session to get rid of selected realm etc.
            }

            # If the session has no realm set, try to get a realm from the map
            elsif (not $session_front->param('pki_realm')) {
                if (not $conf->{realm}->{$script_realm}) {
                    $log->debug('No realm for ident: ' . $script_realm );
                    return $client->new_response(406 => 'I18N_OPENXPKI_UI_NO_SUCH_REALM_OR_SERVICE');
                } else {
                    $detected_realm = $conf->{realm}->{$script_realm};
                }
            }

        } elsif ("hostname" eq $realm_mode) {
            my $host = $ENV{HTTP_HOST};
            $log->trace('Realm map is: ' . Dumper $conf->{realm});
            foreach my $rule (keys %{$conf->{realm}}) {
                next unless ($host =~ qr/\A$rule\z/);
                $log->trace("realm detection match: $host / $rule ");
                $detected_realm = $conf->{realm}->{$rule};
                last;
            }
            $log->warn('Unable to find realm from hostname: ' . $host) unless($detected_realm);

        } elsif ("fixed" eq $realm_mode) {
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

        # custom HTTP headers from config
        $client->response->add_header($_ => $client->config->{header}->{$_}) for keys $client->config->{header}->%*;
        # default mime-type
        $client->response->add_header('content-type' => 'application/json; charset=UTF-8');

        my $page = $client->handle_ui_request; # isa OpenXPKI::Client::Service::WebUI::Page
        $client->response->result($page);
        return $client->response;
    }); # cgi_safe_sub

    send_response($cgi, $client, $response);

    $log->debug('Finished request handling');

    # write session changes
    $session_front->flush if $session_front;
    # detach backend
    $backend_client->detach if $backend_client;
}

$log->info('End fcgi loop ' . $$);

1;
