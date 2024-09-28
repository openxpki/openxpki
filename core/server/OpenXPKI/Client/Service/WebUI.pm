package OpenXPKI::Client::Service::WebUI;
use OpenXPKI qw( -class -typeconstraints );

with qw(
    OpenXPKI::Client::Service::Role::Info
    OpenXPKI::Client::Service::Role::Base
);

# Core modules
use List::Util qw( any );
use Encode;
use MIME::Base64;
use Module::Load ();
use Digest::SHA qw(sha1_base64);

# CPAN modules
use Crypt::JWT qw( encode_jwt decode_jwt );
use URI::Escape;
use Log::Log4perl::MDC;
use LWP::UserAgent;
use Crypt::CBC;
use List::MoreUtils qw( firstidx );

# Project modules
use OpenXPKI::Dumper;
use OpenXPKI::Template;
use OpenXPKI::Client;
use OpenXPKI::Client::Service::WebUI::Bootstrap;
use OpenXPKI::Client::Service::WebUI::Login;
use OpenXPKI::Client::Service::WebUI::Request;
use OpenXPKI::Client::Service::WebUI::Response;
use OpenXPKI::Client::Service::WebUI::Result;
use OpenXPKI::Client::Service::WebUI::Session;
use OpenXPKI::Client::Service::WebUI::SessionCookie;
use OpenXPKI::i18n qw( i18n_walk );


# cipher object to encryt/decrypt protected values
has cipher => (
    init_arg => undef, # set in BUILD
    is => 'rw',
    isa => 'Crypt::CBC',
    predicate => 'has_cipher',
);

# holds key object to sign socket communication
has auth => (
    init_arg => undef, # set in BUILD
    is => 'rw',
    isa => 'Ref',
    predicate => 'has_auth',
);

# session cookie
has session_cookie => (
    init_arg => undef,
    is => 'rw',
    isa => 'OpenXPKI::Client::Service::WebUI::SessionCookie',
    lazy => 1,
    builder => '_build_session_cookie',
);
sub _build_session_cookie ($self) {
    my $insecure_cookie = $self->request->headers->header('X-OpenXPKI-Ember-HTTP-Proxy') ? 1 : 0;
    $self->log->debug('Creating insecure cookie for HTTP proxy (header "X-OpenXPKI-Ember-HTTP-Proxy" found)')
        if $insecure_cookie;

    return OpenXPKI::Client::Service::WebUI::SessionCookie->new(
        request => $self->request,
        $self->has_cipher ? (cipher => $self->cipher) : (),
        insecure => $insecure_cookie, # flag to skip "secure" option in cookie
    );
}

# frontend session
has session => (
    init_arg => undef,
    is => 'rw', # "rw" as it may be refreshed
    isa => 'OpenXPKI::Client::Service::WebUI::Session|Undef',
    lazy => 1,
    predicate => 'has_session',
    builder => '_build_session',
);
sub _build_session ($self) {
    my $id;

    # OIDC session
    # TODO - we might want to embed this into the session handler
    if (
        $self->request->url->to_abs->path->parts->[-1] eq 'oidc_redirect'
        and (my $oidc_state = $self->request->param('state'))
    ) {
        try {
            # the state paramater is the (encrypted) session id
            # wrapped into a HMAC JWT using the extid cookie
            $self->log->debug('Restore session from OIDC redirect');
            my $hash_key = $self->request->cookie('oxi-extid') || die 'Unable to find CSRF cookie';
            my $state = decode_jwt( key => $hash_key, token => $oidc_state );
            $self->log->trace('Decoded state = ' . Dumper $state) if $self->log->is_trace;
            $id = $state->{session_id};
            $id = $self->cipher->decrypt(decode_base64($id)) if $self->has_cipher;
            # TODO - need to handle errors here!
        }
        catch ($err) {
            $self->log->error($err);
            die $self->new_response(401 => 'I18N_OPENXPKI_UI_OIDC_LOGIN_FAILED');
        }

    # Session from cookie
    } else {
        try {
            $id = $self->session_cookie->fetch_id;
        }
        catch ($err) {
            $self->log->error($err);
        }
    }

    Log::Log4perl::MDC->remove;
    if ($id) {
        Log::Log4perl::MDC->put('sid', substr($id,0,4));
        $self->log->debug("Previous frontend session ID read from cookie = $id");
    } else {
        $self->log->debug("No previous frontend session ID found in cookie (or no cookie)");
    }

    #
    # Frontend session
    #
    my $session = OpenXPKI::Client::Service::WebUI::Session->new(
        $self->config->{session}->{driver},
        $id, # may be undef
        $self->config->{session_driver}
            ? $self->config->{session_driver}
            : { Directory => '/tmp' },
    );
    $session->expire($self->config->{session}->{timeout})
        if defined $self->config->{session}->{timeout};

    Log::Log4perl::MDC->put('sid', substr($session->id,0,4));
    $self->log->debug(
        'Frontend session ID = ' . $session->id .
        ($session->expire ? ', expiration = ' . $session->expire : '')
    );
    return $session;
}

# backend (server communication)
has backend => (
    is => 'rw',
    isa => 'OpenXPKI::Client',
    predicate => 'has_backend',
    trigger => \&_init_backend,
);

# Creates an instance of OpenXPKI::Client and switch/create backend session
sub _init_backend ($self, $client) {
    my $id = $client->get_session_id;
    my $old_id = $self->session->param('backend_session_id') || undef;

    if ($old_id and $id and $old_id eq $id) {
        $self->log->debug('Backend session already loaded');
    } else {
        eval {
            $self->log->debug('Backend session: try re-init with ID = ' . ($old_id || '<undef>'));
            $client->init_session({ SESSION_ID => $old_id });
        };
        if (my $eval_err = $EVAL_ERROR) {
            my $exc = OpenXPKI::Exception->caught;
            if ($exc && $exc->message eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
                $self->log->debug('Backend session was gone - start a new one');
                # The session has gone - start a new one - might happen if the GUI
                # was idle too long or the server was flushed
                $client->init_session({ SESSION_ID => undef });
                $self->_ui_response->status->warn('I18N_OPENXPKI_UI_BACKEND_SESSION_GONE');
            } else {
                $self->log->error('Error creating backend session: ' . $eval_err->{message});
                $self->log->trace($eval_err);
                die "Backend communication problem";
            }
        }
        # refresh variable to current id
        $id = $client->get_session_id;
    }

    # logging stuff only
    if ($old_id) {
        if ($id eq $old_id) {
            $self->log->info("Backend session resumed, ID = $id");
        } else {
            $self->log->info("Backend session newly created, ID = $id (re-init failed for old ID $old_id)");
        }
    } else {
        $self->log->info("Backend session newly created, ID = $id");
    }
    $self->session->param('backend_session_id', $id);

    Log::Log4perl::MDC->put('ssid', substr($id,0,4));
}

has realm_mode => (
    init_arg => undef,
    is => 'ro',
    isa => enum([qw(
        select
        path
        hostname
        fixed
    )]),
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{realm_mode} || 'select' },
);

has realm_layout => (
    init_arg => undef,
    is => 'ro',
    isa => enum([qw(
        card
        list
    )]),
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{realm_layout} || 'card' },
);

has socket_path => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{'socket'} },
);

has script_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{scripturl} },
);

has login_page => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{loginpage} // '' },
);

has login_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{loginurl} // '' },
);

has static_dir => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{staticdir} || '/var/www' },
);

# Only if realm_mode=path: a map of realms to URL paths
# {
#     realma => [
#         { url => 'realm-a', stack => 'LocalPassword' },
#         { url => 'realm-a-cert', stack => 'Certificate' },
#     ],
#     realmb => ...
# }
has realm_path_map => (
    init_arg => undef,
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_realm_path_map',
);
sub _build_realm_path_map ($self) {
    my $map = {};
    my $path = $self->url_path->clone->trailing_slash(1);
    for my $url_alias (keys $self->config->{realm}->%*) {
        my ($realm, $stack) = split (/\s*;\s*/, $self->config->{realm}->{$url_alias});
        $path->parts->[-1] = $url_alias;
        $map->{$realm} //= [];
        push $map->{$realm}->@*, {
            url => $path->to_string,
            stack => $stack,
        }
    };
    $self->log->trace('URL path and auth stacks by realm: ' . Dumper($map)) if $self->log->is_trace;
    return $map;
}

has url_path => (
    init_arg => undef,
    is => 'rw',
    isa => 'Mojo::Path',
    lazy => 1,
    default => sub ($self) {
        my $path = $self->request->url->to_abs->path->clone->trailing_slash(0); # remove trailing slash

        # Strip off /cgi-bin/xxx
        my $i = firstidx { $_ eq 'cgi-bin' } $path->parts->@*;
        splice $path->parts->@*, $i if $i != -1;

        $self->log->debug('Sanitized script path = ' . $path->to_string);
        return $path;
    },
);

has response => (
    init_arg => undef,
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::Response',
    lazy => 1,
    default => sub ($self) {
        return $self->new_response;
    },
);

# PRIVATE ATTRIBUTES

has _ui_request => (
    init_arg => undef,
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI::Request',
    lazy => 1,
    default => sub ($self) {
        return OpenXPKI::Client::Service::WebUI::Request->new(
            mojo_request => $self->request,
            log => $self->log,
            session => $self->session,
        );
    },
);

# Response structure (JSON or some raw bytes) and HTTP headers
has _ui_response => (
    init_arg => undef,
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI::Response',
    lazy => 1,
    default => sub ($self) {
        return OpenXPKI::Client::Service::WebUI::Response->new(
            session_cookie => $self->session_cookie,
        );
    },
);


sub BUILD ($self, $args) {
    # Config - set defaults
    $self->config->{global}->{socket} ||= '/var/openxpki/openxpki.socket';
    $self->config->{global}->{scripturl} ||= '/cgi-bin/webui.fcgi';

    # Config - legacy config compatibility
    if ($self->config->{global}->{session_path} || defined $self->config->{global}->{ip_match} || $self->config->{global}->{session_timeout}) {
        if ($self->config->{session}) {
            $self->log->error('Session parameters found both in [global] and [session] - ignoring [global]');
        } else {
            $self->log->warn('Session parameters in [global] are deprecated, please use [session]');
            $self->config->{session} = {
                'ip_match' => $self->config->{global}->{ip_match} || 0,
                'timeout' => $self->config->{global}->{session_timeout} || undef,
            };
            $self->config->{session_driver} = { Directory => ( $self->config->{global}->{session_path} || '/tmp') };
        }
    }

    if (($self->config->{session}->{driver}//'') eq 'openxpki') {
        $self->log->warn("Builtin session driver is deprecated and will be removed with next release!");
    }

    $self->log->trace('Request cookies: ' . ($self->request->headers->cookie // '(none)')) if $self->log->is_trace;

    # Cookie cipher
    if (my $cipher = $self->_get_cipher) {
        $self->cipher($cipher);
    }

    if (my $key = $self->config->{auth}->{'sign.key'}) {
        my $pk = decode_base64($key);
        $self->auth(\$pk);
    }

    # set AUTH stack
    if ($self->config->{login} && $self->config->{login}->{stack}) {
        $self->request->env->{OPENXPKI_AUTH_STACK} = $self->config->{login}->{stack};
    }

    if ($self->config->{session}->{ip_match}) {
        $CGI::Session::IP_MATCH = 1;
    }

    # Session
    if (not $self->session->param('initialized')) {
        $self->session->param('initialized', 1);
        $self->session->param('is_logged_in', 0);
        $self->session->param('user', undef);

    } elsif (my $user = $self->session->param('user')) {
        Log::Log4perl::MDC->put('name', $user->{name});
        Log::Log4perl::MDC->put('role', $user->{role});

    } else {
        Log::Log4perl::MDC->put('name', undef);
        Log::Log4perl::MDC->put('role', undef);
    }
}

sub _get_cipher ($self) {
    # Sets the Crypt::CBC cipher to use for cookie encryption if session.cookey
    # config entry is defined.
    my $key = $self->config->{session}->{cookie} || $self->config->{session}->{cookey} || '';
    # Fingerprint: a list of ENV variables, added to the cookie passphrase,
    # binds the cookie encyption to the system environment.
    # Even though Crypt::CBC will run a hash on the passphrase we still use
    # sha256 here to preprocess the input data one by one to keep the memory
    # footprint as small as possible.
    if (my $fingerprint = $self->config->{session}->{fingerprint}) {
        chomp $fingerprint;
        $self->log->trace("Fingerprint for cookie encryption = '$fingerprint'");
        my $sha = Digest::SHA->new('sha256');
        $sha->add($key) if $key;
        my @env_vars = split /\W+/, $fingerprint;
        map { $sha->add($self->request->env->{$_}) if $self->request->env->{$_} } @env_vars;
        $key = $sha->digest;
    }
    return unless $key;

    $self->log->trace(sprintf('Cookie encryption key: %*vx', '', $key)) if $self->log->trace;

    my $cipher = Crypt::CBC->new(
        -key => $key,
        -pbkdf => 'opensslv2',
        -cipher => 'Crypt::OpenSSL::AES',
    );
    return $cipher;
}

# required by OpenXPKI::Client::Service::Role::Info
sub declare_routes ($r) {
    # WebUI URLs as of 3.26
    $r->any('/webui/<realm>')->to(
        service_class => __PACKAGE__,
        endpoint => 0,
        # OpenXPKI::Client::Service::Role::Base->_build_config() will pass the
        # falsy endpoint to OpenXPKI::Client::Config->endpoint_config() which
        # will then load the default() config
    );
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare ($self, $c) {
    $self->operation('default');

    #
    # Backend (server communication)
    #
    try {
        my $backend = OpenXPKI::Client->new({
            SOCKETFILE => $self->config->{global}->{socket}
        });
        $backend->send_receive_service_msg('PING');
        $self->backend($backend);
    }
    catch ($err) {
        $self->log->error("Error creating backend client: $err");
        die $self->new_response(503 => 'I18N_OPENXPKI_UI_BACKEND_UNREACHABLE');
    }

    #
    # Detect realm
    #
    my $detected_realm;

    my $realm_mode = $self->realm_mode;
    $self->log->debug("Realm mode = $realm_mode");

    # PATH mode
    if ("path" eq $realm_mode) {
        # Set the path to the directory component of the script, this
        # automagically creates seperate cookies for path based realms
        $self->session_cookie->path($self->url_path->to_string);

        # Interpret last part of the URL path as realm
        my $realm = $c->stash('realm');

        # Prepare realm selection
        if ('index' eq $realm) {
            $self->log->debug('Special path "index" - showing realm selection page');

            # Enforce new session to get rid of selected realm etc.
            $self->session->flush;
            $self->backend->detach;
        }

        # If the session has no realm set, try to get a realm from the map
        elsif (not $self->session->param('pki_realm')) {
            $self->log->debug("Checking config for realm '$realm'");
            $detected_realm = $self->config->{realm}->{$realm};
            if (not $detected_realm) {
                $self->log->debug("Unknown realm requested: '$realm'");
                return $self->new_response(406 => 'I18N_OPENXPKI_UI_NO_SUCH_REALM_OR_SERVICE');
            }

        # realm already stored in session
        } else {
            $self->log->debug("Using realm previously stored in session: '$realm'");
        }

    } elsif ("hostname" eq $realm_mode) {
        my $host = $ENV{HTTP_HOST};
        $self->log->trace('Realm map is: ' . Dumper $self->config->{realm});
        foreach my $rule (keys %{$self->config->{realm}}) {
            next unless ($host =~ qr/\A$rule\z/);
            $self->log->trace("realm detection match: $host / $rule ");
            $detected_realm = $self->config->{realm}->{$rule};
            last;
        }
        $self->log->warn('Unable to find realm from hostname: ' . $host) unless($detected_realm);

    } elsif ("fixed" eq $realm_mode) {
        # Fixed realm mode, mode must be defined in the config
        $detected_realm = $self->config->{global}->{realm};
    }

    if ($detected_realm) {
        $self->log->debug("Storing detected realm '$detected_realm' in session");
        my ($realm, $stack) = split /\s*;\s*/, $detected_realm;
        $self->session->param('pki_realm', $realm);
        if ($stack) {
            $self->log->debug("Auto-select auth stack '$stack' based on realm config");
            $self->session->param('auth_stack', $stack);
        }
    }
}

# optionally called by OpenXPKI::Client::Service::Role::Base
sub cleanup ($self) {
    # write session changes
    $self->session->flush if $self->has_session;
    # detach backend
    $self->backend->detach if $self->has_backend;
}

# required by OpenXPKI::Client::Service::Role::Base
sub send_response ($self, $c, $response) {
    if ($response->has_error) {
        if ($self->request->headers->header('X-OPENXPKI-Client')) {
            return $c->render(
                data => $self->json->encode({
                    status => {
                        level => 'error',
                        message => $response->error_message,
                    }
                }),
                format => 'json',
            );
        } else {
            my $error = $response->error_message;
            return $c->render(
                data => <<"EOF",
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
                format => 'html',
            );
        }
    }

    my $page = $response->result; # OpenXPKI::Client::Service::WebUI::Result
    my $ui_resp = $page->ui_response; # OpenXPKI::Client::Service::WebUI::Response

    $c->res->cookies($self->session_cookie->as_mojo_cookies($self->session)->@*);

    # File download
    if ($page->has_raw_bytes or $page->has_raw_bytes_callback) {
        # A) raw bytes in memory
        if ($page->has_raw_bytes) {
            $self->log->debug("Sending raw bytes (in memory)");
            return $c->render(data => $page->raw_bytes);
        }
        # B) raw bytes retrieved by callback function
        elsif ($page->has_raw_bytes_callback) {
            $self->log->debug("Sending raw bytes (via callback)");
            # run callback, passing the write() function as argument
            $page->raw_bytes_callback->(sub { $self->res->content->write(@_) });
            return $c->rendered;
        }

    # Standard JSON response
    } elsif ($self->request->headers->header('X-OPENXPKI-Client')) {
        $self->log->debug("Sending JSON response");
        return $c->render(
            data => $self->ui_response_to_json($ui_resp),
            format => 'json'
        );

    # Redirects
    } else {
        my $url = '';
        # redirect to given page
        if ($ui_resp->redirect->is_set) {
            $url = $ui_resp->redirect->to;

        # redirect to downloads / page pages
        } elsif (my $body = $self->ui_response_to_json($ui_resp)) {
            $url = $self->persist_response( { data => $body } );
        }

        $self->log->debug("Raw redirect target: $url");

        # if url does not start with http or slash, prepend baseurl + route name
        if ($url !~ m{\A http|/}x) {
            my $baseurl = $self->session->param('baseurl') || $self->request->param('baseurl');
            $self->log->debug("Adding baseurl $baseurl");
            $url = sprintf("%s/#/openxpki/%s", $baseurl, $url);
        }
        # HTTP redirect
        $self->log->debug("Sending HTTP redirect to: $url");
        $c->res->code(302);
        return $c->redirect_to($url);
    }
}

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers {
    return [
        'default' => sub ($self) {
            return $self->handle;
        },
    ];
}

# required by OpenXPKI::Client::Service::Role::Base
sub cgi_set_custom_wf_params {}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result {}

sub handle ($self) {
    # custom HTTP headers from config
    $self->response->add_header($_ => $self->config->{header}->{$_}) for keys $self->config->{header}->%*;
    # default mime-type
    $self->response->add_header('content-type' => 'application/json; charset=UTF-8');

    my $ui_response = $self->handle_ui_request; # isa OpenXPKI::Client::Service::WebUI::Result
    $self->response->result($ui_response);
    return $self->response;
}

sub handle_ui_request ($self) {
    my $page = $self->_ui_request->param('page') || '';
    my $action = $self->_get_action;

    $self->log->debug('Incoming request: ' . join(', ', $page ? "page '$page'" : (), $action ? "action '$action'" : ()));

    # Check for goto redirection first
    if ($action =~ /^redirect!(.+)/  || $page =~ /^redirect!(.+)/) {
        my $goto = $1;
        if ($goto =~ m{[^\w\-\!]}) {
            $goto = 'home';
            $self->log->warn("Invalid redirect target found - aborting");
        }
        $self->log->debug("Redirect to: $goto");
        my $result = OpenXPKI::Client::Service::WebUI::Result->new(client => $self);
        $result->redirect->to($goto);
        return $result;
    }

    # Handle logout / session restart
    # Do this before connecting the server to have the client in the
    # new session and to recover from backend session failure
    if ($page eq 'logout' || $action eq 'logout') {

        # For SSO Logins the session might hold an external link
        # to logout from the SSO provider
        my $authinfo = $self->session->param('authinfo') || {};
        my $redirectTo = $authinfo->{logout};

        # clear the session before redirecting to make sure we are safe
        $self->logout_session;
        $self->log->info('Logout from session');

        # now perform the redirect if set
        if ($redirectTo) {
            $self->log->debug("External redirect on logout to: $redirectTo");
            my $result = OpenXPKI::Client::Service::WebUI::Result->new(client => $self);
            $result->redirect->to($redirectTo);
            return $result;
        }

    }

    my $reply = $self->backend->send_receive_service_msg('PING');
    my $status = $reply->{SERVICE_MSG};
    $self->log->trace('PING reply = ' . Dumper $reply) if $self->log->is_trace;
    $self->log->debug("Current session status: $status");

    if ( $reply->{SERVICE_MSG} eq 'START_SESSION' ) {
        $reply = $self->backend->init_session;
        $self->log->debug('Init new session');
        $self->log->trace('NEW_SESSION reply = ' . Dumper $reply) if $self->log->is_trace;
    }

    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        $self->log->debug('Got error from server');
        return OpenXPKI::Client::Service::WebUI::Result->new(client => $self)->set_status_from_error_reply($reply);
    }

    # Only handle requests if we have an open channel (unless it's the bootstrap page)
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' or $page =~ /^bootstrap!(.+)/) {
        return $self->handle_page($page || 'home', $action);
    }

    # if the backend session logged out but did not terminate
    # we get the problem that ui is logged in but backend is not
    $self->logout_session if $self->session->param('is_logged_in');

    # try to log in
    return $self->handle_login($reply);

}

=head2 _load_class

Expect the page/action string and a reference to the cgi object
Extracts the expected class and method name and extra params encoded in
the given parameter and tries to instantiate the class. On success, the
class instance and the extracted method name is returned (two element
array). On error, both elements in the array are set to undef.

=cut

signature_for _load_class => (
    method => 1,
    named => [
        call => 'Str',
        is_action  => 'Bool', { default => 0 },
    ],
);
sub _load_class ($self, $arg) {
    $self->log->debug("Trying to load class for call: " . $arg->call);

    my ($class, $remainder) = ($arg->call =~ /\A (\w+)\!? (.*) \z/xms);
    my ($method, $param_raw);

    if (not $class) {
        $self->log->error("Failed to parse page load string: " . $arg->call);
        return;
    }

    # the request is encoded in an encrypted jwt structure
    if ($class eq 'encrypted') {
        # as the token has non-word characters the above regex does not contain the full payload
        # we therefore read the payload directly from call stripping the class name
        my $decrypted = $self->_ui_request->_decrypt_jwt($remainder) or return;
        if ($decrypted->{page}) {
            $self->log->debug("Encrypted request with page " . $decrypted->{page});
            ($class, $method) = ($decrypted->{page} =~ /\A (\w+)\!? (\w+)? \z/xms);
        } else {
            $class = $decrypted->{class};
            $method = $decrypted->{method};
        }
        my $secure_params = $decrypted->{secure_param} // {};
        $self->log->debug("Encrypted request to $class / $method");
        $self->log->trace("Secure params: " . Dumper $secure_params) if ($self->log->is_trace and keys $secure_params->%*);
        $self->_ui_request->add_secure_params($secure_params->%*);
    }
    else {
        ($method, $param_raw) = ($remainder =~ /\A (\w+)? \!?(.*) \z/xms);
        if ($param_raw) {
            my $params = {};
            my @parts = split /!/, $param_raw;
            while (my $key = shift @parts) {
                my $val = shift @parts // '';
                $params->{$key} = Encode::decode("UTF-8", uri_unescape($val));
            }
            $self->log->trace("Found extra params: " . Dumper $params) if $self->log->is_trace;
            $self->_ui_request->add_params($params->%*);
        }
    }

    $method  = 'index' unless $method;
    my $fullmethod = $arg->is_action ? "action_$method" : "init_$method";

    my @variants;
    # action!...
    if ($arg->is_action) {
        @variants = (
            sprintf("OpenXPKI::Client::Service::WebUI::%s::Action::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::%s::%s", ucfirst($class), $fullmethod),
            sprintf("OpenXPKI::Client::Service::WebUI::%s::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::%s::Action", ucfirst($class)),
            sprintf("OpenXPKI::Client::Service::WebUI::%s", ucfirst($class)),
        );
    }
    # init!...
    else {
        @variants = (
            sprintf("OpenXPKI::Client::Service::WebUI::%s::Init::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::%s::%s", ucfirst($class), $fullmethod),
            sprintf("OpenXPKI::Client::Service::WebUI::%s::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::%s::Init", ucfirst($class)),
            sprintf("OpenXPKI::Client::Service::WebUI::%s", ucfirst($class)),
        );
    }

    for my $pkg (@variants) {
        try {
            Module::Load::load($pkg);
            $self->log->debug("$pkg loaded, testing method availability");
        }
        catch ($err) {
            next if $err =~ /^Can't locate/;
            die $err;
        }

        die "Package $pkg must inherit from OpenXPKI::Client::Service::WebUI::Result"
            unless $pkg->isa('OpenXPKI::Client::Service::WebUI::Result');

        my $obj = $pkg->new(client => $self);

        return ($obj, $fullmethod) if $obj->can($fullmethod);
    }

    $self->log->error(sprintf(
        'Could not find any handler class OpenXPKI::Client::Service::WebUI::%s::* containing %s()',
        ucfirst($class),
        $fullmethod
    ));
    return;
}


=head2 _get_action

Returns the value of the request parameter L<action> if set and the XSRFtoken is
valid. If the token is invalid, returns L<undef> and sets the global status to
error. If the parameter is empty or not set an empty string is returned.

=cut

sub _get_action ($self) {
    my $rtoken_session = $self->session->param('rtoken') || '';
    my $rtoken_request = $self->_ui_request->param('_rtoken') || '';

    # check XSRF token
    if (my $action = $self->_ui_request->param('action')) {
        if ($rtoken_request && ($rtoken_request eq $rtoken_session)) {
            $self->log->debug("Action '$action': valid request");
            return $action;

        # required to make the login page work when the session expires, #552
        } elsif( !$rtoken_session and ($action =~ /^login\!/ )) {
            $self->log->debug("Action '$action': login with expired session, ignoring rtoken");
            return $action;

        } else {
            $self->log->debug("Action '$action': request with invalid rtoken ($rtoken_request != $rtoken_session)");
            $self->_ui_response->status->error('I18N_OPENXPKI_UI_REQUEST_TOKEN_NOT_VALID');
            return '';
        }

    } else {
        return '';
    }
}

sub _jwt_signature ($self, $data, $jws) {
    return unless $self->has_auth;

    $self->log->debug('Sign data using key id ' . $jws->{keyid} );
    my $pkey = $self->auth;
    return encode_jwt(payload => {
        param => $data,
        sid => $self->backend->get_session_id,
    }, key=> $pkey, auto_iat => 1, alg=>'ES256');
}

signature_for handle_page => (
    method => 1,
    positional => [
        'Str',
        'Str', { optional => 1 },
    ],
);
sub handle_page ($self, $page, $action) {
    # Set action or page - args always wins over CGI.
    # Action is only valid within a post request
    my $result;
    my @page_method_args;
    my $redirected_from;

    if ($action) {
        $self->log->info("Handle action '$action'");
        my $method;
        ($result, $method) = $self->_load_class(call => $action, is_action => 1);

        if ($result) {
            $self->log->debug("Calling method: $method()");
            $result->$method();
            # Follow an internal redirect to an init_* method
            if (my $target = $result->internal_redirect_target) {
                ($page, @page_method_args) = $target->@*;
                $redirected_from = $result;
                $self->log->trace("Internal redirect to: $page") if $self->log->is_trace;
            }
        } else {
            $self->_ui_response->status->error('I18N_OPENXPKI_UI_ACTION_NOT_FOUND');
        }
    }

    die "'page' is not set" unless $page;

    # Render a page only if there is no action or object instantiation failed
    if (not $result or $redirected_from) {
        # Special page requests
        $page = 'home!welcome' if $page eq 'welcome';

        $self->log->info("Handle page '$page'");
        my $method;
        ($result, $method) = $self->_load_class(call => $page);

        if ($result) {
            $self->log->debug("Calling method: $method()");
            $result->status($redirected_from->status) if $redirected_from;
            $result->$method(@page_method_args);

        } else {
            $result = OpenXPKI::Client::Service::WebUI::Bootstrap->new(client => $self)->page_not_found;
        }
    }

    Log::Log4perl::MDC->put('wfid', undef);

    return $result;
}

signature_for handle_login => (
    method => 1,
    positional => [
        'HashRef',
    ],
);
sub handle_login ($self, $reply) {
    my $uilogin = OpenXPKI::Client::Service::WebUI::Login->new(client => $self);

    # Login works in three steps realm -> auth stack -> credentials

    my $session = $self->session;
    my $page = $self->_ui_request->param('page') || '';

    # this is the incoming logout action
    if ($page eq 'logout') {
        $uilogin->redirect->to('login!logout');
        return $uilogin;
    }

    # this is the redirect to the "you have been logged out page"
    if ($page eq 'login!logout') {
        $uilogin->init_logout;
        return $uilogin;
    }

    # action is only valid within a post request
    my $action = $self->_get_action;

    $self->log->info("Not logged in. Doing auth. page = '$page', action = '$action'");

    # Special handling for pki_realm and stack params
    if ($action eq 'login!realm' && $self->_ui_request->param('pki_realm')) {
        $self->session->param('pki_realm', scalar $self->_ui_request->param('pki_realm'));
        $self->session->param('auth_stack', undef);
        $self->log->debug('set realm in session: ' . $self->_ui_request->param('pki_realm') );
    }
    if($action eq 'login!stack' && $self->_ui_request->param('auth_stack')) {
        $self->session->param('auth_stack', scalar $self->_ui_request->param('auth_stack'));
        $self->log->debug('set auth_stack in session: ' . $self->_ui_request->param('auth_stack') );
    }

    # ENV always overrides session, keep this after the above block to prevent
    # people from hacking into the session parameters
    if ($self->request->env->{OPENXPKI_PKI_REALM}) {
        $self->session->param('pki_realm', $self->request->env->{OPENXPKI_PKI_REALM});
    }
    if ($self->request->env->{OPENXPKI_AUTH_STACK}) {
        $self->session->param('auth_stack', $self->request->env->{OPENXPKI_AUTH_STACK});
    }

    my $pki_realm = $self->session->param('pki_realm') || '';
    my $auth_stack =  $self->session->param('auth_stack') || '';

    # if this is an initial request, force redirect to the login page
    # will do an external redirect in case loginurl is set in config
    if ($action !~ /^login/ && $page !~ /^login/) {
        # Requests to pages can be redirected after login, store page in session
        if ($page && $page ne 'logout' && $page ne 'welcome') {
            $self->log->debug("Store page request in session for later redirect: $page");
            $self->session->param('redirect', $page);
        }

        # Link to an internal method using the class!method
        if (my $loginpage = $self->login_page) {

            $self->log->debug("Store page request in session for later redirect: $page");
            return $self->handle_page($loginpage);

        } elsif (my $loginurl = $self->login_url) {

            $self->log->debug("Redirect to external login page: $loginurl");
            $uilogin->redirect->external($loginurl);
            return $uilogin;

        } elsif ( $self->request->headers->header('X-OPENXPKI-Client') ) {

            # Session is gone but we are still in the ember application
            $uilogin->redirect->to('login');

        } else {

            # This is not an ember request so we need to redirect
            # back to the ember page - try if the session has a baseurl
            my $url = $self->session->param('baseurl');
            # if not, get the path from the referer
            if (not $url && (($self->request->headers->referrer//'') =~ m{https?://[^/]+(/[\w/]*[\w])/?}i)) {
                $url = $1;
                $self->log->debug('Restore redirect from referer');
            }
            $url .= '/#/openxpki/login';
            $self->log->debug('Redirect to login page: ' . $url);
            $uilogin->redirect->to($url);
        }
    }

    my $status = $reply->{SERVICE_MSG};

    if ( $status eq 'GET_PKI_REALM' ) {
        $self->log->debug("Status: '$status'");
        # realm set
        if ($pki_realm) {
            $reply = $self->backend->send_receive_service_msg( 'GET_PKI_REALM', { PKI_REALM => $pki_realm, } );
            $status = $reply->{SERVICE_MSG};
            $self->log->debug("Selected realm: '$pki_realm', new status: '$status'");
        # no realm set
        } else {
            my $realms = $reply->{PARAMS}->{PKI_REALMS};

            my $safe_realm_str = sub {
                my $r = lc(shift);
                $r =~ s/[_\s]/-/g;
                $r =~ s/[^a-z0-9-]//g;
                $r =~ s/-+/-/g;
                "oxi-realm-card-$r"
            };

            my @cards;
            # "path" mode: realm cards are links to defined sub paths
            if ('path' eq $self->realm_mode) {
                # use webui config but only take realms known to the server:
                my @realm_list =
                    sort { lc($realms->{$a}->{LABEL}) cmp lc($realms->{$b}->{LABEL}) }
                    grep { $realms->{$_} }
                    keys $self->realm_path_map->%*;

                # create a link for each <realm URL path> = <realm> + <auth stack>
                for my $realm (@realm_list) {
                    my $auth_stacks = $realms->{$realm}->{AUTH_STACKS};

                    my @defs = $self->realm_path_map->{$realm}->@*;
                    for my $def (@defs) {
                        my $stack = $def->{stack};
                        my $footer = $stack
                            ? ($auth_stacks->{$stack} ? $auth_stacks->{$stack}->{label} : $stack)
                            : '';
                        push @cards, {
                            label => $realms->{$realm}->{LABEL},
                            description => $realms->{$realm}->{DESCRIPTION},
                            footer => $footer,
                            image => $realms->{$realm}->{IMAGE},
                            color => $realms->{$realm}->{COLOR},
                            css_class => $safe_realm_str->($realm),
                            href => $def->{url},
                        };
                    }
                }

            # other modes: realm cards are actions that set the "pki_realm" parameter
            } else {
                @cards =
                    map { {
                        label => $realms->{$_}->{LABEL},
                        description => $realms->{$_}->{DESCRIPTION},
                        image => $realms->{$_}->{IMAGE},
                        color => $realms->{$_}->{COLOR},
                        css_class => $safe_realm_str->($_),
                        action => 'login!realm',
                        action_params => {
                            pki_realm => $realms->{$_}->{NAME},
                        },
                    } }
                    sort { lc($realms->{$a}->{LABEL}) cmp lc($realms->{$b}->{LABEL}) }
                    keys %{$realms};
            }

            $uilogin->init_realm_cards(\@cards, $self->realm_layout eq 'list' ? 1 : 0);
            return $uilogin;
        }
    }

    if ( $status eq 'GET_AUTHENTICATION_STACK' ) {
        $self->log->debug("Status: '$status'");
        # Never auth with an internal stack!
        if ( $auth_stack && $auth_stack !~ /^_/) {
            $self->log->debug("Authentication stack: $auth_stack");
            $reply = $self->backend->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', {
               AUTHENTICATION_STACK => $auth_stack
            });
            $status = $reply->{SERVICE_MSG};
        } else {
            my $stacks = $reply->{'PARAMS'}->{'AUTHENTICATION_STACKS'};

            # List stacks and hide those starting with an underscore
            my @stack_list =
                map { {
                    'value' => $stacks->{$_}->{name},
                    'label' => $stacks->{$_}->{label},
                    'description' => $stacks->{$_}->{description}
                } }
                grep { $stacks->{$_}->{name} !~ /^_/ }
                keys $stacks->%*;

            # Directly load stack if there is only one
            if (scalar @stack_list == 1)  {
                $auth_stack = $stack_list[0]->{value};
                $self->session->param('auth_stack', $auth_stack);
                $self->log->debug("Only one stack avail ($auth_stack) - autoselect");
                $reply = $self->backend->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', {
                    AUTHENTICATION_STACK => $auth_stack
                } );
                $status = $reply->{SERVICE_MSG};
            } else {
                $self->log->trace("Offering stacks: " . Dumper \@stack_list ) if $self->log->is_trace;
                $uilogin->init_auth_stack(\@stack_list);
                return $uilogin;
            }
        }
    }

    $self->log->debug("Selected realm $pki_realm, new status " . $status);
    $self->log->trace('Reply: ' . Dumper $reply) if $self->log->is_trace;

    # we have more than one login handler and leave it to the login
    # class to render it right.
    if ( $status =~ /GET_(.*)_LOGIN/ ) {
        $self->log->debug("Status: '$status'");
        my $login_type = $1;

        ## FIXME - need a good way to configure login handlers
        $self->log->info('Requested login type ' . $login_type );
        my $auth = $reply->{PARAMS};
        my $jws = $reply->{SIGN};

        # SSO Login uses data from the ENV, so no need to render anything
        if ( $login_type eq 'CLIENT' ) {

            $self->log->trace('ENV is ' . Dumper \%ENV) if $self->log->is_trace;
            my $data;
            if ($auth->{envkeys}) {
                foreach my $key (keys %{$auth->{envkeys}}) {
                    my $envkey = $auth->{envkeys}->{$key};
                    $self->log->debug("Try to load $key from $envkey");
                    next unless defined $self->request->env->{$envkey};
                    $data->{$key} = Encode::decode('UTF-8', $self->request->env->{$envkey}, Encode::LEAVE_SRC | Encode::FB_CROAK);
                }
            # legacy support
            } elsif (my $user = $self->request->env->{'OPENXPKI_USER'} || $self->request->env->{'REMOTE_USER'} || '') {
                $data->{username} = $user;
                $data->{role} = $self->request->env->{'OPENXPKI_GROUP'} if($self->request->env->{'OPENXPKI_GROUP'});
            }

            # at least some items were found so we send them to the backend
            if ($data) {
                $self->log->trace('Sending auth data ' . Dumper $data) if $self->log->is_trace;

                $data = $self->_jwt_signature($data, $jws) if ($jws);

                $reply = $self->backend->send_receive_service_msg( 'GET_CLIENT_LOGIN', $data );

            # as nothing was found we do not even try to login in and look for a redirect
            } elsif (my $loginurl = $auth->{login}) {

                # the login url might contain a backlink to the running instance
                $loginurl = OpenXPKI::Template->new->render( $loginurl,
                    { baseurl => $self->session->param('baseurl') } );

                $self->log->debug("No auth data in environment - redirect found $loginurl");
                $uilogin->redirect->external($loginurl);
                return $uilogin;

            # bad luck - something seems to be really wrong
            } else {
                $self->log->error('No ENV data to perform SSO Login');
                $self->logout_session;
                $uilogin->init_login_missing_data;
                return $uilogin;
            }

        } elsif ( $login_type eq 'X509' ) {
            my $user = $self->request->env->{'SSL_CLIENT_S_DN_CN'} || $self->request->env->{'SSL_CLIENT_S_DN'};
            my $cert = $self->request->env->{'SSL_CLIENT_CERT'} || '';

            $self->log->trace('ENV is ' . Dumper \%ENV) if $self->log->is_trace;

            if ($cert) {
                $self->log->info('Sending X509 Login ( '.$user.' )');
                my @chain;
                # larger chains are very unlikely and we dont support stupid clients
                for (my $cc=0;$cc<=3;$cc++)   {
                    my $chaincert = $self->request->env->{'SSL_CLIENT_CERT_CHAIN_'.$cc};
                    last unless ($chaincert);
                    push @chain, $chaincert;
                }

                my $data = { certificate => $cert, chain => \@chain };
                $data = $self->_jwt_signature($data, $jws) if ($jws);

                $reply =  $self->backend->send_receive_service_msg( 'GET_X509_LOGIN', $data);
                $self->log->trace('Auth result ' . Dumper $reply) if $self->log->is_trace;
            } else {
                $self->log->error('Certificate missing for X509 Login');
                $self->logout_session;
                $uilogin->init_login_missing_data;
                return $uilogin;
            }

        } elsif( $login_type  eq 'OIDC' ) {

            my %oidc_client = map {
                ($_ => ($auth->{$_} || die "OIDC setup incomplete, $_ is not set"));
            } qw(client_id auth_uri token_uri client_secret);

            $self->log->trace(SDumper \%oidc_client) if ($self->log->is_trace);

            # we use "page" to transport the token
            if ($page =~ m{login!oidc!token!([\w\-\.]+)\z}) {
                # Step 3 - use token to perform authentication
                my $token = $1;
                $self->log->debug('OIDC Login (3/3) - present token to backend');
                $self->log->trace($token);
                my $nonce = $self->session->param('oidc-nonce');
                return $uilogin->init_login_missing_data unless ($nonce);

                $self->session->param('oidc-nonce' => undef);
                $reply = $self->backend->send_receive_service_msg( 'GET_OIDC_LOGIN', {
                    token => $token,
                    client_id => $oidc_client{client_id},
                    nonce => $nonce,
                });

            } else {

                my $tt = OpenXPKI::Template->new;
                my $uri_pattern = $auth->{redirect_uri} || 'https://[% host _ baseurl %]';
                my $redirect_uri = $tt->render( $uri_pattern, {
                    host => $self->request->url->host,
                    baseurl => $self->session->param('baseurl'),
                    realm =>   $pki_realm,
                    stack =>   $auth_stack,
                });

                if (my $code = $self->_ui_request->param('code')) {

                    # Step 2 - user was redirected from IdP
                    $self->log->debug("OIDC Login (2/3) - redeem auth code $code");
                    my $ua = LWP::UserAgent->new;
                    # For whatever reason this must be www-form encoded and not JSON
                    my $response = $ua->post( $oidc_client{token_uri}, [
                        code => $code,
                        client_id => $oidc_client{client_id},
                        client_secret => $oidc_client{client_secret},
                        redirect_uri => $redirect_uri.'/oidc_redirect',
                        grant_type => 'authorization_code',
                    ]);
                    $self->log->trace("OIDC Token Response: " .$response->decoded_content);
                    if (!$response->is_success) {
                        $self->log->warn("Unable to redeem token, error was: " . $response->decoded_content);
                        $uilogin->status->error('Unable to redeem token');
                        $uilogin->redirect->to('login!missing_data');
                        return $uilogin;
                    }
                    my $auth_info = $self->json->decode($response->decoded_content);
                    $uilogin->redirect->to('login!oidc!token!'.$auth_info->{id_token});
                    return $uilogin;

                } elsif ($self->session->param('oidc-nonce')) {

                    # to avoid an endless loop in case the user is not willing
                    # or able to complete the OIDC login, we use the nonce
                    # in the session to detect a "returning user" and render an
                    # info page instead of doing a redirect
                    $self->logout_session;
                    return $uilogin->init_login_missing_data;

                } else {

                    # Initial step - assemble auth token request and send redirect
                    my $nonce = Data::UUID->new->create_b64;
                    my $sess_id = $self->has_cipher ?
                        encode_base64($self->cipher->encrypt($self->session->id),'') :
                        $self->session->id;

                    # TODO - this is only set if we had a roundtrip before
                    # move this into the session
                    my $hash_key = $self->request->cookie('oxi-extid');
                    my $auth_token = {
                        response_type => 'code',
                        client_id => $oidc_client{client_id},
                        scope => ($auth->{scope} || 'openid profile email'),
                        redirect_uri => $redirect_uri.'/oidc_redirect',
                        state => encode_jwt( alg => 'HS256', key => $hash_key, payload => {
                            session_id => $sess_id,
                            baseurl => $redirect_uri,
                        }),
                        nonce => $nonce,
                    };
                    $self->log->debug('OIDC Login (1/3) - redirect to ' . $oidc_client{auth_uri});
                    $self->session->param('oidc-nonce',$nonce);
                    my $loginurl = $oidc_client{auth_uri}.'?'.join('&', (map { $_ .'='. uri_escape($auth_token->{$_})  } keys %{$auth_token}));
                    $uilogin->redirect->external($loginurl);
                    return $uilogin;
                }
            }

        } elsif( $login_type eq 'PASSWD' ) {

            # form send / credentials are passed (works with an empty form too...)

            if ($action eq 'login!password') {
                $self->log->debug('Seems to be an auth try - validating');
                ##FIXME - Input validation

                my $data;
                my @fields = $auth->{field} ?
                    (map { $_->{name} } @{$auth->{field}}) :
                    ('username','password');

                foreach my $field (@fields) {
                    my $val = $self->_ui_request->param($field);
                    next unless ($val);
                    $data->{$field} = $val;
                }

                $data = $self->_jwt_signature($data, $jws) if ($jws);

                $reply = $self->backend->send_receive_service_msg( 'GET_PASSWD_LOGIN', $data );
                $self->log->trace('Auth result ' . Dumper $reply) if $self->log->is_trace;

            } else {
                $self->log->debug('No credentials, render form');
                $uilogin->init_login_passwd($auth);
                return $uilogin;
            }

        } else {

            $self->log->warn('Unknown login type ' . $login_type );
        }
    }

    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {
        $self->log->info('Authentication successul - fetch session info');
        # Fetch the user info from the server
        $reply = $self->backend->send_receive_service_msg( 'COMMAND',
            { COMMAND => 'get_session_info', PARAMS => {}, API => 2 } );

        if ( $reply->{SERVICE_MSG} eq 'COMMAND' ) {

            my $session_info = $reply->{PARAMS};

            # merge baseurl to authinfo links
            # (we need to get the baseurl before recreating the session below)
            my $auth_info = {};
            my $baseurl = $self->session->param('baseurl');
            if (my $ai = $session_info->{authinfo}) {
                my $tt = OpenXPKI::Template->new;
                for my $key (keys %{$ai}) {
                    $auth_info->{$key} = $tt->render( $ai->{$key}, { baseurl => $baseurl } );
                }
            }
            delete $session_info->{authinfo};

            #$self->backend->rekey_session;
            #my $new_backend_session_id = $self->backend->get_session_id;

            # Generate a new frontend session to prevent session fixation
            # The backend session remains the same but can not be used by an
            # adversary as the id is never exposed and we destroy the old frontend
            # session so access to the old session is not possible
            $self->_recreate_frontend_session($session_info, $auth_info);

            if ($auth_info->{login}) {
                $uilogin->redirect->to($auth_info->{login});
            } else {
                $uilogin->init_index;
            }
            return $uilogin;
        }
    }

    if ( $reply->{SERVICE_MSG} eq 'ERROR') {

        $self->log->trace('Server Error Msg: '. Dumper $reply) if $self->log->is_trace;

        # Failure here is likely a wrong password

        if ($reply->{'ERROR'} && $reply->{'ERROR'}->{CLASS} eq 'OpenXPKI::Exception::Authentication') {
            $uilogin->status->error($reply->{'ERROR'}->{LABEL});
        } else {
            $uilogin->set_status_from_error_reply($reply);
        }
        return $uilogin;
    }

    $self->log->debug("unhandled error during auth");
    return;

}

sub _new_frontend_session {

    my $self = shift;

    # create new session object but reuse old settings
    $self->session($self->session->clone);

    Log::Log4perl::MDC->put('sid', substr($self->session->id,0,4));
    $self->log->debug('New frontend session: ID = '. $self->session->id);

}

sub _recreate_frontend_session {

    my $self = shift;
    my $session_info = shift; # as returned from API command "get_session_info"
    my $auth_info = shift;

    $self->log->trace('Got session info: '. Dumper $session_info) if $self->log->is_trace;

    # fetch redirect from old session before deleting it!
    my %keep = map {
        my $val = $self->session->param($_);
        (defined $val) ? ($_ => $val) : ();
    } ('redirect','baseurl');

    $self->log->trace("Carry over session items: " . Dumper \%keep) if ($self->log->is_trace);

    # create a new session
    $self->_new_frontend_session;

    map { $self->session->param($_, $keep{$_}) } keys %keep;

    # set some data
    $self->session->param('backend_session_id', $self->backend->get_session_id );

    # move userinfo to own node
    $self->session->param('userinfo', $session_info->{userinfo} || {});
    delete $session_info->{userinfo};

    $self->session->param('authinfo', $auth_info);

    $self->session->param('user', $session_info);
    $self->session->param('pki_realm', $session_info->{pki_realm});
    $self->session->param('is_logged_in', 1);
    $self->session->param('initialized', 1);
    $self->session->param('login_timestamp', time);

    # Check for MOTD, e.g. { level => 'warn', message => 'Beware!' }
    my $motd = $self->backend->send_receive_command_msg( 'get_motd' );
    if (ref $motd->{PARAMS} eq 'HASH') {
        $self->log->trace('Got MOTD: '. Dumper $motd->{PARAMS} ) if $self->log->is_trace;
        $self->session->param('motd', $motd->{PARAMS} );
    }

    # menu
    my $reply = $self->backend->send_receive_command_msg( 'get_menu' );
    $self->_set_menu($reply->{PARAMS}) if $reply->{PARAMS};

    $self->session->flush;

}

sub _set_menu {
    my $self = shift;
    my $menu = shift;

    $self->log->trace('Menu ' . Dumper $menu) if $self->log->is_trace;

    $self->session->param('menu_items', $menu->{main} || []);

    # persist the optional parts of the menu hash (landmark, tasklist, search attribs)
    $self->session->param('landmark', $menu->{landmark} || {});
    $self->log->trace('Got landmarks: ' . Dumper $menu->{landmark}) if $self->log->is_trace;

    # Keepalive pings to endpoint
    if ($menu->{ping}) {
        my $ping;
        if (ref $menu->{ping} eq 'HASH') {
            $ping = $menu->{ping};
            $ping->{timeout} *= 1000; # Javascript expects timeout in ms
        } else {
            $ping = { href => $menu->{ping}, timeout => 120000 };
        }
        $self->session->param('ping', $ping);
    }

    # tasklist, wfsearch, certsearch and bulk can have multiple branches
    # using named keys. We try to autodetect legacy formats and map
    # those to a "default" key
    # TODO Remove legacy compatibility

    # config items are a list of hashes
    foreach my $key (qw(tasklist bulk)) {

        if (ref $menu->{$key} eq 'ARRAY') {
            $self->session->param($key, { 'default' => $menu->{$key} });
        } elsif (ref $menu->{$key} eq 'HASH') {
            $self->session->param($key, $menu->{$key} );
        } else {
            $self->session->param($key, { 'default' => [] });
        }
        $self->log->trace("Got $key: " . Dumper $menu->{$key}) if $self->log->is_trace;
    }

    # top level is a hash that must have a "attributes" node
    # legacy format was a single list of attributes
    # TODO Remove legacy compatibility
    foreach my $key (qw(wfsearch certsearch)) {

        # plain attributes
        if (ref $menu->{$key} eq 'ARRAY') {
            $self->session->param($key, { 'default' => { attributes => $menu->{$key} } } );
        } elsif (ref $menu->{$key} eq 'HASH') {
            $self->session->param($key, $menu->{$key} );
        } else {
            # empty hash is used to disable the search page
            $self->session->param($key, {} );
        }
        $self->log->trace("Got $key: " . Dumper $menu->{$key}) if $self->log->is_trace;
    }

    foreach my $key (qw(datapool)) {
        if (ref $menu->{$key} eq 'HASH' and $menu->{$key}->{default}) {
            $self->session->param($key, $menu->{$key} );
        } else {
            $self->session->param($key, { default => {} });
        }
        $self->log->trace("Got $key: " . Dumper $menu->{$key}) if $self->log->is_trace;
    }

    # Check syntax of "certdetails".
    # (the sub{} below allows using "return" instead of nested "if"-structures)
    my $certdetails = sub {
        my $result;
        unless ($result = $menu->{certdetails}) {
            $self->log->warn('Config entry "certdetails" is empty');
            return {};
        }
        unless (ref $result eq 'HASH') {
            $self->log->warn('Config entry "certdetails" is not a hash');
            return {};
        }
        if ($result->{metadata}) {
            if (ref $result->{metadata} eq 'ARRAY') {
                for my $md (@{ $result->{metadata} }) {
                    if (not ref $md eq 'HASH') {
                        $self->log->warn('Config entry "certdetails.metadata" contains an item that is not a hash');
                        $result->{metadata} = [];
                        last;
                    }
                }
            }
            else {
                $self->log->warn('Config entry "certdetails.metadata" is not an array');
                $result->{metadata} = [];
            }
        }
        return $result;
    }->();
    $self->session->param('certdetails', $certdetails);

    # Check syntax of "wfdetails".
    # (the sub{} below allows using "return" instead of nested "if"-structures)
    my $wfdetails = sub {
        if (not exists $menu->{wfdetails}) {
            $self->log->debug('Config entry "wfdetails" is not defined, using defaults');
            return [];
        }
        my $result;
        unless ($result = $menu->{wfdetails}) {
            $self->log->debug('Config entry "wfdetails" is set to "undef", hide from output');
            return;
        }
        unless (ref $result eq 'ARRAY') {
            $self->log->warn('Config entry "wfdetails" is not an array');
            return [];
        }
        return $result;
    }->();
    $self->session->param('wfdetails', $wfdetails);
}

=head2 logout_session

Delete and flush the current session and recreate a new one using
the remaining class object. If the internal session handler is used,
the session is cleared but not destreoyed.

If you pass a reference to the CGI handler, the session cookie is updated.
=cut

sub logout_session {

    my $self = shift;

    $self->log->info("session logout");
    $self->backend->logout;

    # create a new session
    $self->_new_frontend_session;

}

=head2 ui_response_to_json

Convert the given UI response DTO L<OpenXPKI::Client::Service::WebUI::Response>
into JSON.

=cut
signature_for ui_response_to_json => (
    method => 1,
    positional => [
        'OpenXPKI::Client::Service::WebUI::Response',
    ],
);
sub ui_response_to_json ($self, $ui_response) {
    my $status = $ui_response->status->is_set ? $ui_response->status->resolve : $self->_fetch_status;

    #
    # A) page redirect
    #
    if ($ui_response->redirect->is_set) {
        if ($status) {
            # persist status and append to redirect URL
            my $url_param = $self->_persist_status($status);
            $ui_response->redirect->to($ui_response->redirect->to . '!' . $url_param);
        }
        return $self->json->encode({
            %{ $ui_response->redirect->resolve },
            session_id => $self->session->id
        });
    }

    #
    # B) response to a confined request, i.e. no page update (auto-complete etc.)
    #
    elsif ($ui_response->has_confined_response) {
        return $self->json->encode(i18n_walk($ui_response->confined_response));
    }

    #
    # C) regular response
    #
    else {
        my $data = $ui_response->resolve; # resolve response DTOs into nested HashRef

        # show message of the day if we have a page section (may overwrite status)
        if ($ui_response->page->is_set && (my $motd = $self->session->param('motd'))) {
            $self->session->param('motd', undef);
            $data->{status} = $motd;
        }

        # add session ID
        $data->{session_id} = $self->session->id;

        return $self->json->encode(i18n_walk($data));
    }
}

sub _persist_status {
    my $self = shift;
    my $status = shift;

    my $session_key = $self->_generate_uid;
    $self->session->param($session_key, $status);
    $self->session->expire($session_key, 15);

    return '_status_id!' . $session_key;
}

sub _fetch_status {
    my $self = shift;

    my $session_key = $self->_ui_request->param('_status_id');
    return unless $session_key;

    my $status = $self->session->param($session_key);
    return unless ($status && ref $status eq 'HASH');

    $self->log->debug("Set persisted status: " . $status->{message});
    return $status;
}

=head2 _generate_uid

Generate a random uid (RFC 3548 URL and filename safe base64)

=cut
sub _generate_uid {
    my $self = shift;
    my $uid = sha1_base64(time.rand.$$);
    ## RFC 3548 URL and filename safe base64
    $uid =~ tr/+\//-_/;
    return $uid;
}

=head2 persist_response

Persist the given response data to retrieve it after an HTTP roundtrip.
Used to break out of the JavaScript app for downloads or to reroute result
pages.

Returns the page call URI for L<OpenXPKI::Client::Service::WebUI::Cache/init_fetch>.

=cut

sub persist_response ($self, $data, $expire = '+5m') {
    die "Attempt to persist empty response data" unless $data;

    my $id = $self->_generate_uid;
    $self->log->debug('persist response ' . $id);

    $self->session->param('response_'.$id, $data );
    $self->session->expire('response_'.$id, $expire) if $expire;

    return "cache!fetch!id!$id";
}

=head2 fetch_response

Get the data for the persisted response.

=cut

sub fetch_response ($self, $id) {
    $self->log->debug('fetch response ' . $id);
    my $response = $self->session->param('response_'.$id);
    if (not $response) {
        $self->log->error( "persisted response with id '$id' does not exist" );
        return;
    }
    return $response;
}

__PACKAGE__->meta->make_immutable;
