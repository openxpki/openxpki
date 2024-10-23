package OpenXPKI::Client::Service::WebUI;
use OpenXPKI qw( -class -typeconstraints );

with qw(
    OpenXPKI::Client::Service::Role::Info
    OpenXPKI::Client::Service::Role::Base
    OpenXPKI::Client::Service::WebUI::Role::RequestParams
    OpenXPKI::Client::Service::WebUI::Role::PageHandler
    OpenXPKI::Client::Service::WebUI::Role::LoginHandler
);

# Core modules
use MIME::Base64;
use Digest::SHA qw(sha1_base64);

# CPAN modules
use Crypt::JWT qw( encode_jwt decode_jwt );
use Crypt::CBC;
use Crypt::PRNG;
use List::MoreUtils qw( firstidx );
use Log::Log4perl::MDC;
use LWP::UserAgent;

# Project modules
use OpenXPKI::Client;
use OpenXPKI::Client::Service::WebUI::Response;
use OpenXPKI::Client::Service::WebUI::Page;
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
sub auth; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
sub has_auth;
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
sub session; # "stub" subroutine to satisfy OpenXPKI::Client::Service::WebUI::Role::Base; will be overwritten by attribute accessor later on
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
                $self->ui_response->status->warn('I18N_OPENXPKI_UI_BACKEND_SESSION_GONE');
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

sub realm_mode; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
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

has static_dir => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{staticdir} || '/var/www' },
);

sub url_path; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
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

# Response structure (JSON or some raw bytes) and HTTP headers
sub ui_response; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has ui_response => (
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

    my $page = $response->result; # OpenXPKI::Client::Service::WebUI::Page
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
            # custom HTTP headers from config
            $self->response->add_header($_ => $self->config->{header}->{$_}) for keys $self->config->{header}->%*;
            # default mime-type
            $self->response->add_header('content-type' => 'application/json; charset=UTF-8');

            my $page = $self->handle_ui_request; # isa OpenXPKI::Client::Service::WebUI::Page
            $self->response->result($page);
            return $self->response;
        },
    ];
}

# required by OpenXPKI::Client::Service::Role::Base
sub cgi_set_custom_wf_params {}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result {}

sub handle_ui_request ($self) {
    my $page = $self->param('page') || '';
    my $action = $self->_get_action;

    $self->log->debug('Incoming request: ' . join(', ', $page ? "page '$page'" : (), $action ? "action '$action'" : ()));

    # shortcut to create new pure Page object for redirecting or error status
    my $new_page = sub ($cb) {
        my $page = OpenXPKI::Client::Service::WebUI::Page->new(client => $self);
        $cb->($page);
        return $page;
    };

    # Check for goto redirection first
    if ($action =~ /^redirect!(.+)/  || $page =~ /^redirect!(.+)/) {
        my $goto = $1;
        if ($goto =~ m{[^\w\-\!]}) {
            $goto = 'home';
            $self->log->warn("Invalid redirect target found - aborting");
        }
        $self->log->debug("Redirect to: $goto");
        return $new_page->(sub { shift->redirect->to($goto) });
    }

    # Handle logout / session restart
    # Do this before connecting the server to have the client in the
    # new session and to recover from backend session failure
    if ($page eq 'logout' or $action eq 'logout') {

        # For SSO Logins the session might hold an external link
        # to logout from the SSO provider
        my $authinfo = $self->session->param('authinfo') || {};
        my $goto = $authinfo->{logout};

        # clear the session before redirecting to make sure we are safe
        $self->logout_session;
        $self->log->info('Logout from session');

        # now perform the redirect if set
        if ($goto) {
            $self->log->debug("External redirect on logout to: $goto");
            return $new_page->(sub { shift->redirect->to($goto) });
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
        return $new_page->(sub ($p) { $p->status->error($p->message_from_error_reply($reply)) });
    }

    # Only handle requests if we have an open channel (unless it's the bootstrap page)
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' or $page =~ /^bootstrap!(.+)/) {
        if ($action) {
            # Action is only valid within a post request
            return $self->handle_action($action); # from OpenXPKI::Client::Service::WebUI::Role::Page
        } else {
            return $self->handle_view($page || 'home'); # from OpenXPKI::Client::Service::WebUI::Role::Page
        }
    }

    # if the backend session logged out but did not terminate
    # we get the problem that ui is logged in but backend is not
    $self->logout_session if $self->session->param('is_logged_in');

    # try to log in
    return $self->handle_login($page || '', $action, $reply); # from OpenXPKI::Client::Service::WebUI::Role::Login

}

=head2 _get_action

Returns the value of the request parameter L<action> if set and the XSRFtoken is
valid. If the token is invalid, returns L<undef> and sets the global status to
error. If the parameter is empty or not set an empty string is returned.

=cut

sub _get_action ($self) {
    my $rtoken_session = $self->session->param('rtoken') || '';
    my $rtoken_request = $self->param('_rtoken') || '';

    # check XSRF token
    if (my $action = $self->param('action')) {
        if ($rtoken_request && ($rtoken_request eq $rtoken_session)) {
            $self->log->debug("Action '$action': valid request");
            return $action;

        # required to make the login page work when the session expires, #552
        } elsif( !$rtoken_session and ($action =~ /^login\!/ )) {
            $self->log->debug("Action '$action': login with expired session, ignoring rtoken");
            return $action;

        } else {
            $self->log->debug("Action '$action': request with invalid rtoken ($rtoken_request != $rtoken_session)");
            $self->ui_response->status->error('I18N_OPENXPKI_UI_REQUEST_TOKEN_NOT_VALID');
            return '';
        }

    } else {
        return '';
    }
}

sub new_frontend_session {

    my $self = shift;

    # create new session object but reuse old settings
    $self->session($self->session->clone);

    Log::Log4perl::MDC->put('sid', substr($self->session->id,0,4));
    $self->log->debug('New frontend session: ID = '. $self->session->id);

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
    $self->new_frontend_session;

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

    my $session_key = $self->generate_uid;
    $self->session->param($session_key, $status);
    $self->session->expire($session_key, 15);

    return '_status_id!' . $session_key;
}

sub _fetch_status {
    my $self = shift;

    my $session_key = $self->param('_status_id');
    return unless $session_key;

    my $status = $self->session->param($session_key);
    return unless ($status && ref $status eq 'HASH');

    $self->log->debug("Set persisted status: " . $status->{message});
    return $status;
}

=head2 generate_uid

Generate a random uid (RFC 3548 URL and filename safe base64)

=cut
sub generate_uid {
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

Returns the page call URI for L<OpenXPKI::Client::Service::WebUI::Page::Cache/init_fetch>.

=cut

sub persist_response ($self, $data, $expire = '+5m') {
    die "Attempt to persist empty response data" unless $data;

    my $id = $self->generate_uid;
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

=head2 encrypt_jwt

Encrypt the given data into a JWT using the encryption key stored in session
parameter C<jwt_encryption_key> (key will be set to random value if it does not
exist yet).

=cut

# required by OpenXPKI::Client::Service::WebUI::Page
sub encrypt_jwt ($self, $value) {
    my $key = $self->session->param('jwt_encryption_key');
    if (not $key) {
        $key = Crypt::PRNG::random_bytes(32);
        $self->session->param('jwt_encryption_key', $key);
    }

    my $token = encode_jwt(
        payload => $value,
        enc => 'A256CBC-HS512',
        alg => 'PBES2-HS512+A256KW', # uses "HMAC-SHA512" as the PRF and "AES256-WRAP" for the encryption scheme
        key => $key, # can be any length for PBES2-HS512+A256KW
        extra_headers => {
            p2c => 8000, # PBES2 iteration count
            p2s => 32,   # PBES2 salt length
        },
    );

    return $token;
}

=head2 decrypt_jwt

Decrypt the given JWT using the encryption key stored in session parameter
C<jwt_encryption_key>.

=cut

# required by OpenXPKI::Client::Service::WebUI::Role::Request
sub decrypt_jwt ($self, $token) {
    return unless $token;

    my $jwt_key = $self->session->param('jwt_encryption_key');
    unless ($jwt_key) {
        $self->log->debug("JWT encrypted parameter received but client session contains no decryption key");
        return;
    }

    my $decrypted = decode_jwt(token => $token, key => $jwt_key);

    return $decrypted;
}

__PACKAGE__->meta->make_immutable;
