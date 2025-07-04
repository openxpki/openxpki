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
use List::Util qw ( max );

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
        path => $self->url_path,
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
        $self->normalized_request_url->path->parts->[-1] eq 'oidc_redirect'
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

    if ($id) {
        Log::Log4perl::MDC->put('sid', substr($id,0,4));
        $self->log->debug("Previous frontend session ID (read from cookie) = $id");
    } else {
        $self->log->debug("No previous frontend session ID found in cookie (or no cookie)");
    }

    #
    # Frontend session
    #
    my $session_dsn = $self->config->get('session.driver') // undef;
    my $session_config = $self->config->get_hash('session.params'); # new format
    $session_config //= $self->config->get_hash('session_driver'); # old format
    $session_config //= { Directory => '/tmp' }; # default for file driver

    my $session = OpenXPKI::Client::Service::WebUI::Session->new(
        $session_dsn, # may be undef
        $id, # may be undef
        $session_config
    );
    $session->expire($self->config->get('session.timeout'))
        if $self->config->exists('session.timeout');

    Log::Log4perl::MDC->put('sid', substr($session->id,0,4));

    if ($self->log->is_debug) {
        my %info = (dsn => $session_dsn, ID => $session->id);
        $info{expires} = $session->expire if $session->expire;
        $self->log->debug('Frontend session: ' . join(', ', map { "$_ = $info{$_}" } sort keys %info));
    }

    return $session;
}

# Overwrite attribute from OpenXPKI::Client::Service::Role::Base
has '+client' => (
    trigger => \&_init_client,
);

# Switch to or create backend session
sub _init_client ($self, $client) {
    my $id = $client->get_session_id;
    my $old_id = $self->session->param('backend_session_id') || undef;

    if ($old_id and $id and $old_id eq $id) {
        $self->log->debug('Backend session already loaded');
    } else {
        eval {
            $self->log->debug('Backend session: try re-init with ID = ' . ($old_id || '<undef>'));
            $client->init_session({ SESSION_ID => $old_id }); # initialize backend session
        };
        if (my $eval_err = $EVAL_ERROR) {
            my $exc = OpenXPKI::Exception->caught;
            if ($exc && $exc->message eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
                $self->log->debug('Backend session was gone - start a new one');
                # The session has gone - start a new one - might happen if the GUI
                # was idle too long or the server was flushed
                $client->init_session({ SESSION_ID => undef }); # initialize backend session
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
            $self->log->debug("Backend session resumed, ID = $id");
        } else {
            $self->log->debug("Backend session newly created, ID = $id (re-init failed for old ID $old_id)");
        }
    } else {
        $self->log->debug("Backend session newly created, ID = $id");
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
    )]),
    lazy => 1,
    default => sub ($self) { $self->config->get('realm.mode') || $self->config->get('global.realm_mode') || 'select' },
);

has realm_layout => (
    init_arg => undef,
    is => 'ro',
    isa => enum([qw(
        card
        list
    )]),
    lazy => 1,
    default => sub ($self) { $self->config->get('realm.layout') || $self->config->get('global.realm_layout') || 'card' },
);

has script_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->get('global.scripturl') // '/cgi-bin/webui.fcgi' },
);

has static_dir => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->get('global.staticdir') || '/var/www' },
);

sub url_path; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has url_path => (
    init_arg => undef,
    is => 'rw',
    isa => 'Mojo::Path',
    lazy => 1,
    default => sub ($self) {
        my $path = $self->normalized_request_url->path->clone;

        # Strip off /cgi-bin/xxx
        my $i = firstidx { $_ eq 'cgi-bin' } $path->parts->@*;
        splice $path->parts->@*, $i if $i != -1;

        $self->log->trace('Sanitized script path: ' . $path->to_string) if $self->log->is_trace;
        return $path;
    },
);

=head2 base_url

Base website URL as sent by the Ember UI (index.html). This may differ from the
URL of the asynchronously called OpenXPKI client, e.g.:

    Ember UI:        https://localhost/webui/democa/
    OpenXPKI Client: https://localhost/cgi-bin/webui.fcgi

This attribute is set from the frontend session parameter C<baseurl> or the
request parameter C<baseurl> in L</prepare>.

The base URL allows us to e.g. issue internal UI redirects (without specifying
the full URL every time).

=cut
sub base_url; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has base_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) {
        my $baseurl;
        # query client session
        if ($baseurl = $self->session->param('baseurl')) {
            $self->log->debug("Base URL obtained from client session: $baseurl");
        # fallback to "Referer" header (Mojolicious provides a method with correct spelling...)
        } elsif (($self->request->headers->referrer//'') =~ m{https?://[^/]+(/[\w/]*[\w])/?}i) {
            $baseurl = $1;
            $self->log->debug("Base URL obtained from HTTP referrer header: $baseurl");
        # default
        } else {
            $baseurl = '/openxpki'; # default is mainly relevant for tests
            $self->log->warn("Base URL set to default: $baseurl");
        }
        # We do the fallback and default handling here and not in BUILD()
        # (where request parameter "baseurl" is queried) to avoid setting
        # the session parameter to a default too early because a later
        # request might provide the "baseurl".
        return $baseurl;
    }
);

sub response; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
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

=head2 action

Returns the value of the request parameter L<action> if set and the XSRFtoken is
valid. If the token is invalid, returns an empty string and sets the response
status to an error message.

If the parameter is empty or not set an empty string is returned.

=cut
sub action; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has action => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) {
        my $rtoken_session = $self->session->param('rtoken') || '';
        my $rtoken_request = $self->param('_rtoken') || '';

        # check XSRF token
        if (my $action = $self->param('action')) {
            if ($rtoken_request && ($rtoken_request eq $rtoken_session)) {
                $self->log->debug("Action '$action': valid request");
                return ($action // '');

            # required to make the login page work when the session expires, #552
            } elsif( !$rtoken_session and ($action =~ /^login\!/ )) {
                $self->log->debug("Action '$action': login with expired session, ignoring rtoken");
                return ($action // '');

            } else {
                $self->log->debug("Action '$action': request with invalid rtoken ($rtoken_request != $rtoken_session)");
                $self->ui_response->status->error('I18N_OPENXPKI_UI_REQUEST_TOKEN_NOT_VALID');
                return '';
            }

        } else {
            return '';
        }
    },
);

=head2 current_realm

Contains the current realm if it could be detected from path or hostname or
read from the client session.

=cut
sub current_realm; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has current_realm => (
    init_arg => undef,
    is => 'rw',
    isa => 'Str',
    predicate => 'has_current_realm',
);

=head2 current_auth_stack

Contains the current stack name if it could be detected from path or hostname or
read from the client session.

=cut
sub current_auth_stack; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has current_auth_stack => (
    init_arg => undef,
    is => 'rw',
    isa => 'Str',
    predicate => 'has_current_auth_stack',
);

=head2

Set to C<1> if the current page is the realm selection page (I<realm_mode>
C<"path"> only).

=cut
sub is_realm_selection_page; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has is_realm_selection_page => (
    init_arg => undef,
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

=head1 METHODS

=head2 url_path_for

Return the URL path L<Str> for the given realm using the pattern of the current
Mojolicious request's route (= the one defined in L</declare_routes>).

=cut

sub url_path_for; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has '_url_path_for' => (
    init_arg => undef,
    is => 'rw',
    isa => 'CodeRef',
    traits => [ 'Code' ],
    handles => {
        'url_path_for' => 'execute',
    },
);

sub BUILD ($self, $args) {
    # Config - set defaults

    # legacy config in global is no longer supported
    die "Session setup in global section is no longer supported"
        if ($self->config->exists('global.session_path'));

    $self->log->trace('Request cookies: ' . ($self->request->headers->cookie // '(none)')) if $self->log->is_trace;

    # Cookie cipher
    if (my $cipher = $self->_get_cipher) {
        $self->cipher($cipher);
    }

    # TODO Rework auth.sign.key handling
    if (my $key = $self->config->get(['auth','sign.key'])) {
        my $pk = decode_base64($key);
        $self->auth(\$pk);
    }

    if ($self->config->get('session.ip_match')) {
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

    # Query base URL from request parameter sent by app/services/oxi-content.js (window.location.pathname)
    # and store it in client session.
    # It is then read by $self->base_url's default method upon access.
    #
    # NOTE: We cannot do this in $self->base_url's attribute default method
    # because the "baseurl" request parameter might not be available in the same
    # request loop when $self->base_url is accessed.
    if (not $self->session->param('baseurl') and my $baseurl = $self->request_param('baseurl')) {
        $baseurl =~ s{(\A\s+|\s+\z|/\z)}{}g;    # strip spaces and trailing slash
        $baseurl =~ s{\w+://[^/]+}{};           # prevent injection of external urls
        $self->log->debug("Store base URL from request parameter in client session: $baseurl");
        $self->session->param('baseurl', $baseurl);
    }
}

sub _get_cipher ($self) {
    # Sets the Crypt::CBC cipher to use for cookie encryption if session.cookey
    # config entry is defined.
    my $key = $self->config->get('session.cookey') || $self->config->get('session.cookie');

    # Fingerprint: a list of ENV variables, added to the cookie passphrase,
    # binds the cookie encyption to the system environment.
    # Even though Crypt::CBC will run a hash on the passphrase we still use
    # sha256 here to preprocess the input data one by one to keep the memory
    # footprint as small as possible.
    if (my @fingerprint = $self->get_list_from_config('session.fingerprint')) {
        my $sha = Digest::SHA->new('sha256');
        $sha->add($key) if $key;

        $self->log->debug('Fingerprint for cookie encryption = ' . join(', ', @fingerprint));
        my $spacer = max(map { length } @fingerprint) + 3;
        for my $key (@fingerprint) {
            my $msg_key = "- $key " . ('.' x ($spacer-length($key)));
            # variable available as is in webserver ENV
            if (my $env = $self->request->env->{$key}) {
                $sha->add($env);
                $self->log->trace("$msg_key found in webserver ENV");
            # variable is an Apache name for an HTTP header
            } elsif ($key =~ /^HTTP_(.*)/) {
                my $header_name = $1; $header_name =~ s/_/-/g;
                if (my $header = $self->request->headers->header($header_name)) {
                    $sha->add($header);
                    $self->log->trace("$msg_key found as HTTP header");
                }
            # variable not found
            } else {
                $self->log->trace("$msg_key not found");
            }
        }

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
        endpoint => 'default',
    );
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare ($self, $c) {
    $self->operation('default');

    # set the method to generate URL paths
    # https://metacpan.org/pod/Mojolicious::Controller#url_for
    $self->_url_path_for( sub($r) { $c->url_for(realm => $r)->to_string } );

    #
    # Detect realm
    #
    my $current_realm;

    my $realm_mode = $self->realm_mode;
    $self->log->debug("Realm detection mode: $realm_mode");

    # PATH mode
    if ("path" eq $realm_mode) {
        # Set the path to the directory component of the script, this
        # automagically creates seperate cookies for path based realms
        $self->session_cookie->path($self->url_path);

        # Interpret last part of the URL path as realm
        my $realm = $c->stash('realm');

        # Prepare realm selection
        if ('index' eq $realm) {
            $self->log->debug('- special path "index"');
            $self->session->param('pki_realm', undef);
            $self->is_realm_selection_page(1);

        # Realm already stored in session
        } elsif (my $session_realm = $self->session->param('pki_realm')) {
            $self->log->debug("- realm '$session_realm' read from client session");
            $self->current_realm($session_realm);
            if (my $session_stack = $self->session->param('auth_stack')) {
                $self->current_auth_stack($session_stack);
            }

        # If the session has no realm set, try to get a realm from the map
        } else {
            $self->log->debug("- realm '$realm' requested via path - reading config");
            $current_realm = $self->config->get(['realm','map', $realm]);

            # TODO Remove legacy config
            $current_realm //= $self->config->get(['realm', $realm]);

            if (not $current_realm) {
                $self->log->info("- realm '$realm' unknown (not found in config)");
                return $self->new_response(404 => 'I18N_OPENXPKI_UI_NO_SUCH_REALM_OR_SERVICE');
            }
        }

    # HOSTNAME mode
    } elsif ("hostname" eq $realm_mode) {
        my $host = $self->normalized_request_url->host // '';
        $self->log->debug("- looking for rule to match host '$host'");
        my $realm_map = $self->config->get_hash('realm.map');

        # TODO Remove legacy config support:
        $realm_map //= $self->config->get_hash('realm');

        $self->log->trace('- realm map = ' . Dumper $realm_map ) if $self->log->is_trace;
        while (my ($pattern, $realm) = each(%$realm_map)) {
            next unless ($host =~ qr/\A$pattern\z/);
            $self->log->debug("- match: pattern = $pattern") if $self->log->is_trace;
            $current_realm = $realm;
            last;
        }
        $self->log->warn("- unable to find matching realm for hostname '$host'") unless $current_realm;

    }

    if ($current_realm) {
        my ($realm, $stack) = split /\s*;\s*/, $current_realm;
        $self->log->debug("- detected realm: '$realm'");
        $self->current_realm($realm);
        if ($stack) {
            $self->log->debug("- auto-selected auth stack based on realm config: '$stack'");
            $self->current_auth_stack($stack);
        }
    }
}

# optionally called by OpenXPKI::Client::Service::Role::Base
sub cleanup ($self) {
    # write session changes to storage + close DB connection (if DBI handler)
    $self->session->flush if $self->has_session;
    # detach backend
    $self->client->detach if $self->has_client;
}

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers {
    return [
        'default' => sub ($self) {
            # default security related headers, may be overwritten by config.
            # Also see https://owasp.org/www-project-secure-headers/ci/headers_add.json
            $self->response->set_header('strict-transport-security' => 'max-age=31536000');
            $self->response->set_header('x-content-type-options' => 'nosniff');
            $self->response->set_header('content-security-policy' =>
                "default-src 'self'; "
                ."form-action 'self'; "
                ."base-uri 'self'; "
                ."object-src 'none'; "
                ."script-src 'self'; "
                ."style-src 'self'; "
                ."img-src 'self' data:; "
                ."font-src 'self'; "
                ."connect-src 'self'; "
                ."frame-ancestors 'none'; "
            );

            # custom HTTP headers from config
            my $headers = $self->config->get_hash('header');
            $self->response->set_header( lc($_) => $headers->{$_} ) for keys %$headers;
            # default mime-type
            $self->response->set_header('content-type' => 'application/json; charset=UTF-8');

            my $page = $self->handle_ui_request; # isa OpenXPKI::Client::Service::WebUI::Page
            $self->response->result($page);
            return $self->response;
        },
    ];
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
            $url = $page->call_persisted_response( { data => $body } );
        }

        $self->log->debug("Raw redirect target: $url");

        # if url does not start with http or slash, prepend baseurl + route name
        if ($url !~ m{\A http|/}x) {
            my $baseurl = $self->base_url;
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
sub cgi_set_custom_wf_params {}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result {}

=head2 handle_ui_request

Main entry point to handle the UI requests after some setup done in L</prepare>.

Returns an instance of L<OpenXPKI::Client::Service::WebUI::Page>.

=cut
sub handle_ui_request ($self) {
    my $page = $self->param('page') || '';
    my $action = $self->action;

    $self->log->info('Incoming request: ' . join(', ', $page ? "page '$page'" : (), $action ? "action '$action'" : ()));

    # Shortcut to create new pure Page object for redirecting or error status
    my $new_page = sub ($cb) {
        my $page = OpenXPKI::Client::Service::WebUI::Page->new(webui => $self);
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
    if (my $logout_page = $self->handle_logout($page)) { # from OpenXPKI::Client::Service::WebUI::Role::LoginHandler
        return $logout_page;
    }

    # Prepare realm selection: enforce new server session to get rid of selected realm etc.
    if ($self->is_realm_selection_page) {
        $self->log->debug('Enforce new server session to prepare realm selection');
        $self->client->detach;
    }

    # Establish backend connection
    my $reply = $self->ping_client;

    if ( $reply->{SERVICE_MSG} eq 'START_SESSION' ) {
        $reply = $self->client->init_session; # initialize backend session
        $self->log->debug('Init new session');
        $self->log->trace('NEW_SESSION reply = ' . Dumper $reply) if $self->log->is_trace;
    }

    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        $self->log->debug('Got error from server');
        return $new_page->(sub ($p) { $p->status->error($p->message_from_error_reply($reply)) });
    }

    # Set logout menu for bootstrap page if we're not logged in (= not SERVICE_READY)
    if ($reply->{SERVICE_MSG} ne 'SERVICE_READY' and not defined $self->session->param('menu_items')) {
        my $reply = $self->client->send_receive_service_msg('GET_LOGOUT_MENU');
        if ($reply->{PARAMS} and my $menu = $reply->{PARAMS}->{main}) {
            $self->log->trace('Received logout menu = ' . Dumper $menu) if $self->log->is_trace;
            $self->session->param('menu_items', $menu);
        }
    }

    # Set pki_realm and auth_stack from auto-detection (URL path or hostname or
    # config) or previous session after logout
    $self->session->param('pki_realm', $self->current_realm) if $self->has_current_realm;
    $self->session->param('auth_stack', $self->current_auth_stack) if $self->has_current_auth_stack;

    # Handle page if logged in (open channel) unless it's the bootstrap page
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' or $page =~ /^bootstrap!(.+)/) {
        if ($action) {
            # Action is only valid within a post request
            return $self->handle_action($action); # from OpenXPKI::Client::Service::WebUI::Role::PageHandler
        } else {
            return $self->handle_view($page || 'home'); # from OpenXPKI::Client::Service::WebUI::Role::PageHandler
        }
    }

    # If the backend session logged out but did not terminate
    # we get the problem that ui is logged in but backend is not
    $self->logout_session if $self->session->param('is_logged_in');

    # Handle login (from OpenXPKI::Client::Service::WebUI::Role::LoginHandler)
    return $self->handle_login($page || '', $action, $reply);
}

=head2 ping_client

Pings the server and returns the received I<SERVICE_MSG>.

=cut

sub ping_client ($self) {
    my $reply = $self->client->send_receive_service_msg('PING');
    $self->log->trace('PING reply = ' . Dumper $reply) if $self->log->is_trace;
    $self->log->debug("Current session status: " . $reply->{SERVICE_MSG});
    return $reply;
}

=head2 new_frontend_session

Create a new frontend session with the same settings as the previous one. The
only preserved data is the C<pki_realm>.

=cut

sub new_frontend_session ($self) {
    my $pki_realm = $self->session->param('pki_realm');

    # create new session object but reuse old settings
    $self->session($self->session->clone);
    $self->session->param(pki_realm => $pki_realm) if $pki_realm;

    Log::Log4perl::MDC->put('sid', substr($self->session->id,0,4));
    $self->log->debug('New frontend session: ID = '. $self->session->id);
}

=head2 logout_session

Logout from the backend session and create a new frontend session while
preserving the C<pki_realm>.

=cut

sub logout_session ($self) {
    $self->log->info("Logout = create new backend and frontend session");
    $self->client->logout;

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

    my $session_key = OpenXPKI::Util->generate_uid;
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
