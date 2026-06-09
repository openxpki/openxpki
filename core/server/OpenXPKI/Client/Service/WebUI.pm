package OpenXPKI::Client::Service::WebUI;
use OpenXPKI qw( -class -typeconstraints );

with qw(
    OpenXPKI::Client::Service::Role::Info
    OpenXPKI::Client::Service::Role::Base
);

=head1 NAME

OpenXPKI::Client::Service::WebUI - service to deliver web page contents via JSON

=head1 DESCRIPTION

Client service class that implements the OpenXPKI web UI JSON API. It
consumes L<OpenXPKI::Client::Service::Role::Info> (route declaration) and
L<OpenXPKI::Client::Service::Role::Base> (request lifecycle).

Each incoming HTTP request is handled by a single instance of this class.
The instance manages the frontend session (cookie-backed, DB-stored via
L<OpenXPKI::Client::Service::WebUI::Session>), the backend connection
(L<OpenXPKI::Client>), realm and auth-stack detection, XSRF token
validation, and JSON response serialization.

=cut

# Core modules
use MIME::Base64;
use List::Util qw ( max );
use Carp;

# CPAN modules
use Crypt::JWT qw( encode_jwt decode_jwt );
use Crypt::CBC;
use List::MoreUtils qw( firstidx );
use Log::Log4perl::MDC;

# Project modules
use OpenXPKI::Client;
use OpenXPKI::Client::Service::WebUI::RequestParams;
use OpenXPKI::Client::Service::WebUI::Response;
use OpenXPKI::Client::Service::WebUI::Page;
use OpenXPKI::Client::Service::WebUI::Session;
use OpenXPKI::Client::Service::WebUI::SessionCookie;
use OpenXPKI::Client::Service::WebUI::Auth;
use OpenXPKI::Client::Service::WebUI::Dispatcher;
use OpenXPKI::i18n qw( i18n_walk );

=head1 ATTRIBUTES

=head2 cipher

L<Crypt::CBC> cipher object to encryt/decrypt protected values. Auto-set if
config value is set.

Config values: C<session.cookey> aka. C<session.cookie_secret>

=cut
has cipher => (
    init_arg => undef, # set in BUILD
    is => 'rw',
    lazy => 1,
    isa => 'Crypt::CBC|Undef',
    builder => '_get_cipher',
);

# Autobuilder is required for OIDC session restore but attribute
# can be undef in case encryption is not configured
sub has_cipher {
    my $cipher = shift->cipher();
    return (defined $cipher);
}

=head2 session_cookie

HTTP session cookie encapsulation (L<OpenXPKI::Client::Service::WebUI::SessionCookie>).
Auto-created.

The cookie will be encrypted if L</cipher> is set.

=cut
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

=head2 session

Frontend/client session (L<OpenXPKI::Client::Service::WebUI::Session>).
Auto-created.

Config values: C<session.driver>, C<session.params>, C<session.timeout>

=cut
sub session; # pre-declaration required so Role::Base requirement is met before attribute accessor is defined
has session => (
    init_arg => undef,
    is => 'rw', # "rw" as it may be refreshed
    isa => 'OpenXPKI::Client::Service::WebUI::Session::Role|Undef',
    lazy => 1,
    predicate => 'has_session',
    builder => '_build_session',
);
# Parse new session config syntax (2026-01+): session.database
# Returns ($db_params, $encrypt_key, $log_ip).
# Takes only the HashRef from session.database so the logic can be tested without a full WebUI object.
sub _parse_new_session_config {
    my ($new_db_conf) = @_;

    my $db_conf = { %$new_db_conf }; # copy so we can delete from it

    # Extract session-specific parameters (not part of db_params)
    my $encrypt_key = delete $db_conf->{encrypt_key};
    my $log_ip      = delete $db_conf->{log_ip};

    # 'password' is an alias for 'passwd' (compatibility with server DB config)
    if (exists $db_conf->{password}) {
        my $pw = delete $db_conf->{password};
        $db_conf->{passwd} //= $pw;
    }

    # 'namespace' stays in db_params: OpenXPKI::Database driver uses it to
    # prefix table names in all queries (e.g. Oracle schema)
    return ($db_conf, $encrypt_key, $log_ip);
}

# Parse old session config syntax (pre 2026-01): session.driver + session.params / session_driver
# Returns ($db_params, $encrypt_key, $log_ip).
# Takes the raw config values so the logic can be tested without a full WebUI object.
#
# Parameters:
#   $old_conf   - HashRef from session.params / session_driver
sub _parse_old_session_config {
    my ($old_conf) = @_;

    my $conf = $old_conf ? { %$old_conf } : {}; # copy so we can delete from it

    # Extract session-specific parameters
    my $encrypt_key = delete $conf->{EncryptKey};
    my $log_ip      = delete $conf->{LogIP};

    # Parse the DataSource DSN (dbi:Driver:key=val;...) into db_params
    my $datasource = delete $conf->{DataSource}
        or die "Session config: missing 'DataSource' in session driver config\n";

    my ($dbi_driver, $driver_dsn) = $datasource =~ m{^dbi:([^:]+):(.*)$}i;
    die "Session config: cannot parse DataSource '$datasource'\n" unless $dbi_driver;

    # Map DBI driver names to OpenXPKI::Database type names
    my %dbi_to_type = (
        mysql   => 'MySQL',
        mariadb => 'MariaDB2',
        pg      => 'PostgreSQL',
        oracle  => 'Oracle',
        sqlite  => 'SQLite',
    );
    my $type = $dbi_to_type{ lc($dbi_driver) }
        or die "Session config: unsupported DBI driver '$dbi_driver' in DataSource\n";

    # Parse the driver-specific DSN part: collect key=value pairs and bare tokens separately
    my (@dsn_extra, %dsn_params);
    for (split /;/, $driver_dsn) {
        if (/=/) { my ($k, $v) = split /=/, $_, 2; $dsn_params{$k} = $v }
        else      { push @dsn_extra, $_ }
    }

    my $db_params = {
        type      => $type,
        name      => delete($dsn_params{database}) // delete($dsn_params{dbname}) // delete($dsn_params{db}),
        host      => delete $dsn_params{host},
        port      => delete $dsn_params{port},
        user      => delete $conf->{User},
        passwd    => delete($conf->{Password}) // delete($conf->{passwd}),
        namespace => delete $conf->{NameSpace},
        # Pass any unrecognised DSN parameters through as dsn_extra
        (@dsn_extra || %dsn_params) ? (dbi => { dsn_extra => join(';', @dsn_extra, map { "$_=$dsn_params{$_}" } sort keys %dsn_params) }) : (),
    };

    # DBI connect attributes (set via session.params / session_driver in old format)
    if (my $attrs = delete $conf->{dbi_connect_attrs}) {
        $db_params->{dbi} //= {};
        $db_params->{dbi}{attrs} = $attrs;
    }

    return ($db_params, $encrypt_key, $log_ip);
}

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
            my $state = decode_jwt( key => $hash_key->value, token => $oidc_state );
            $self->log->trace('Decoded state = ' . Dumper $state) if $self->log->is_trace;
            $id = $state->{session_id};
            $id = $self->cipher->decrypt(decode_base64($id)) if $self->has_cipher;

            $self->log->trace('Decoded Frontend Session ID: ' . $id);
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
            $self->log->info($err);
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
    my ($legacy_file_session, $db_params, $encrypt_key, $log_ip);

    # Recent config syntax (since 2026-01)
    if (my $conf = $self->config->get_hash('session.database')) {
        ($db_params, $encrypt_key, $log_ip) = _parse_new_session_config($conf);

    # Old config syntax (pre 2026-01)
    } else {
        my $driver = $self->config->get('session.driver');
        # die "Session config: file-based sessions are no longer supported, please migrate to 'session.database'\n"
        #     if ($driver//'') ne 'driver:openxpki';

        $conf = $self->config->get_hash('session.params');   # new format (.yaml)
        $conf //= $self->config->get_hash('session_driver'); # old format (.conf)

        # Legacy File driver
        if (($driver//'') ne 'driver:openxpki') {
            $conf //= { Directory => '/tmp' };
            require OpenXPKI::Client::Service::WebUI::LegacyCGISession;
            $legacy_file_session = OpenXPKI::Client::Service::WebUI::LegacyCGISession->new_patched(
                $driver, # may be undef
                $id,     # may be undef
                $conf
            );
        } else {
            # Default LongReadLen for Oracle
            $conf->{LongReadLen} = $conf->{LongReadLen} // 100000;

            ($db_params, $encrypt_key, $log_ip) = _parse_old_session_config($conf);
        }
    }

    my $session = $legacy_file_session // OpenXPKI::Client::Service::WebUI::Session->new(
        db_params  => $db_params,
        id         => $id,
        defined($encrypt_key) ? (encrypt_key => $encrypt_key) : (),
        defined($log_ip)      ? (log_ip      => $log_ip)      : (),
    );
    $session->expire($self->config->get('session.timeout'))
        if $self->config->exists('session.timeout');

    Log::Log4perl::MDC->put('sid', substr($session->id,0,4));

    if ($self->log->is_debug) {
        my %info = (
            id => $session->id,
            $session->expire ? (expires => $session->expire) : (),
        );
        $self->log->debug('Frontend session: ' . join(', ', map { "$_ = $info{$_}" } sort keys %info));
    }

    return $session;
}

=head2 client

L<OpenXPKI::Client::Service::Role::Base/client> is overwritten to add a Moose
trigger. The trigger will read client session parameter C<backend_session_id>
and try to re-use this session. If that fails or no ID was stored then a new
backend session is created.

=cut
# Overwrite attribute from OpenXPKI::Client::Service::Role::Base
has '+client' => (
    trigger => \&_init_client,
);

# Switch to or create backend session
sub _init_client ($self, $client) {
    my $id = $client->get_session_id;
    my $old_id = $self->session->param('backend_session_id') || undef;

    if ($old_id and $id and $old_id eq $id) {
        $self->log->trace('Backend session already loaded');
    } else {
        eval {
            $self->log->trace('Backend session: try re-init with ID = ' . ($old_id || '<undef>'));
            $client->init_session({ SESSION_ID => $old_id }); # initialize backend session
        };
        if (my $eval_err = $EVAL_ERROR) {
            my $exc = OpenXPKI::Exception->caught;
            if ($exc && $exc->message eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
                $self->log->trace('Backend session was gone - start a new one');
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

=head2 realm_mode

Shortcut for config value C<realm.mode> to determine the current realm:
C<"select">, C<"path"> or C<"hostname">. Default: C<"select">. Auto-initialized.

=cut
sub realm_mode;
has realm_mode => (
    init_arg => undef,
    is => 'ro',
    isa => enum([qw(
        select
        path
        hostname
    )]),
    lazy => 1,
    default => sub ($self) {
        $self->config->get('realm.mode') || $self->config->get('global.realm_mode') || 'select'
},
);

=head2 realm_selection_page

The requested realm selection page C<PAGE>, read from URL C</webui/index-PAGE>.
The default is C<"default"> (if URL is C</webui/index>).

Defines  the config path to be queried for the realm selection page layout:
C<webui.*.realm.selection.PAGE>.

Set in L</prepare>. Unknown page names will be changed to C<"default">.

=head2 is_realm_selection_page

Set to C<1> if the current page is the realm selection page (I<realm_mode>
C<"path"> only).

=cut
sub realm_selection_page;
sub is_realm_selection_page;
has realm_selection_page => (
    init_arg => undef,
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    predicate => 'is_realm_selection_page',
    default => sub { confess "Attempt to read realm selection page before it was set" },
);

=head2 realm_selection_conf

Config hash C<realm.selection.PAGE> that contains the realm selection definition.
Auto-initialized.

Ensures at least the C<layout> key is always present (defaults to 'card'):

    say $self->realm_selection_conf->{layout};

Legacy config values C<realm.layout> and C<global.realm_layout> are mapped into
C<realm.selection.PAGE.layout>.

Must be called after L</realm_selection_page> was set.

=cut
has realm_selection_conf => (
    init_arg => undef,
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub ($self) {
        # realm.selection may be a plain string or a hash with a "layout" key
        my $conf = $self->config->get_hash(['realm', 'selection', $self->realm_selection_page]) // {};
        if (not $conf->{layout}) {
            $conf->{layout} =
                # TODO Legacy config options for realm selection layout: realm.layout and global.realm_layout
                $self->config->get('realm.layout')
             || $self->config->get('global.realm_layout')
             || 'card';
        }
        return $conf;
    },
);

=head2 script_url

In Mojolicious this is fixed: C<"/cgi-bin/webui.fcgi">. The only usage is to
distinct the request from static assets access in the webserver. Auto-initialized.

=cut
has script_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->get('global.scripturl') // '/cgi-bin/webui.fcgi' },
);

=head2 static_dir

Shortcut for config value C<global.staticdir>: filesystem path to the directory
containing static web assets. Default: C<"/var/www">. Auto-initialized.

=cut
has static_dir => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->get('global.staticdir') || '/var/www' },
);

=head2 url_path

Normalized request URL path (leading, but no trailing slash) with
C</cgi-bin/xxx> stripped off.

E.g. C<"/webui/democa">. Auto-initialized.

=cut
sub url_path;
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
the full URL every time). Auto-initialized.

=cut
sub base_url;
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

=head2 auth

Instance of L<OpenXPKI::Client::Service::WebUI::Auth>. Auto-created.

=cut
has auth => (
    init_arg => undef,
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI::Auth',
    lazy => 1,
    default => sub ($self) {
        OpenXPKI::Client::Service::WebUI::Auth->new(webui => $self)
    },
);

=head2 dispatcher

Instance of L<OpenXPKI::Client::Service::WebUI::Dispatcher>. Auto-created.

=cut
has dispatcher => (
    init_arg => undef,
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI::Dispatcher',
    lazy => 1,
    default => sub ($self) {
        OpenXPKI::Client::Service::WebUI::Dispatcher->new(webui => $self)
    },
);

=head2 response

Generic HTTP response encapsulation (L<OpenXPKI::Client::Service::Response>).
Auto-created.

=cut
sub response;
has response => (
    init_arg => undef,
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::Response',
    lazy => 1,
    default => sub ($self) {
        return $self->new_response;
    },
);

=head2 ui_response

L<OpenXPKI::Client::Service::WebUI::Response> object encapsulating the web UI
specific JSON response. Auto-created, L</session_cookie> gets passed.

=cut
# Response structure (JSON or some raw bytes) and HTTP headers
sub ui_response;
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
valid. If the token is invalid, returns an empty string and sets the
L</ui_response> status to an error message.

If the parameter is empty or not set an empty string is returned. Auto-initialized.

=cut
sub action;
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
                $self->log->debug("Action '$action': XSRF token valid");
                return ($action // '');

            # required to make the login page work when the session expires, #552
            } elsif( !$rtoken_session and ($action =~ /^login\!/ )) {
                $self->log->debug("Action '$action': login with expired session, ignoring XSRF token");
                return ($action // '');

            } else {
                $self->log->debug("Action '$action': request with invalid XSRF token ($rtoken_request != $rtoken_session)");
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
sub current_realm;
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
sub current_auth_stack;
has current_auth_stack => (
    init_arg => undef,
    is => 'rw',
    isa => 'Str',
    predicate => 'has_current_auth_stack',
);

=head2 request_params

L<OpenXPKI::Client::Service::WebUI::RequestParams> instance that parses and
caches request parameters for the current HTTP request. Auto-initialized.

=cut

has request_params => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'OpenXPKI::Client::Service::WebUI::RequestParams',
    lazy     => 1,
    default  => sub ($self) {
        OpenXPKI::Client::Service::WebUI::RequestParams->new(
            request => $self->request,
            session => $self->session,
            json    => $self->json,
        )
    },
    handles  => [qw( param multi_param secure_param add_params add_secure_params )],
);

=head1 METHODS

=head2 url_path_for

Return the URL path L<Str> for the given realm using the pattern of the current
Mojolicious request's route (= the one defined in L</declare_routes>).

=cut

sub url_path_for;
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

    # Init Cookie cipher
    $self->cipher();

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
    # config entry is defined. (cookey = COOkie encryption KEY)
    my $key = $self->config->get('session.cookey') || $self->config->get('session.cookie_secret');

    # Fingerprint: a list of ENV variables, added to the cookie passphrase,
    # binds the cookie encyption to the system environment.
    # Even though Crypt::CBC will run a hash on the passphrase we still use
    # sha256 here to preprocess the input data one by one to keep the memory
    # footprint as small as possible.
    if (my @fingerprint = $self->get_list_from_config('session.fingerprint')) {
        my $sha = Digest::SHA->new('sha256');
        $sha->add($key) if $key;

        $self->log->trace('Fingerprint for cookie encryption = ' . join(', ', @fingerprint));
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
    $r->any(['GET'] => '/webui/<realmpath>/oidc_redirect')->to(
        service_class => __PACKAGE__,
        endpoint => 'default',
        operation => 'oidc_redirect',
    );

    $r->any('/webui/<realmpath>')->to(
        service_class => __PACKAGE__,
        endpoint => 'default',
    );
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare ($self, $c) {
    $self->operation($c->stash('operation') // 'default');

    # set the method to generate URL paths
    # https://metacpan.org/pod/Mojolicious::Controller#url_for
    $self->_url_path_for( sub($r) { $c->url_for(realmpath => $r)->to_string } );

    #
    # Detect realm
    #
    my $current_realm;

    my $realm_mode = $self->realm_mode;
    $self->log->debug("Realm detection mode: $realm_mode");

    # PATH mode
    if ("path" eq $realm_mode) {
        # Set the path to the directory component of the script, this
        # automagically creates separate cookies for path based realms
        $self->session_cookie->path($self->url_path);

        # Interpret last part of the URL path as realm
        my $realmpath = $c->stash('realmpath')
            or die "Path does not contain realm hint";

        # Request to realm selection page: "/webui/index" or "/webui/index-page"
        if (my ($page) = $realmpath =~ /\Aindex(?:\-(.+))?\z/) {
            $self->log->debug('- special path "index"');
            $self->session->param('pki_realm', undef);
            $self->realm_selection_page($page // 'default');

        # Realm already stored in session
        } elsif (my $session_realm = $self->session->param('pki_realm')) {
            $self->log->debug("- realm '$session_realm' read from client session");
            $self->current_realm($session_realm);
            if (my $session_stack = $self->session->param('auth_stack')) {
                $self->current_auth_stack($session_stack);
            }

        # If the session has no realm set, try to get a realm from the map
        } else {
            $self->log->debug("- looking up path->realm mapping for '$realmpath'");
            $current_realm = $self->config->get(['realm','map', $realmpath]);

            # TODO Remove legacy config support for path->realm map directly at webui.x.realm
            $current_realm //= $self->config->get(['realm', $realmpath]);

            if (not $current_realm) {
                $self->log->info("- realm '$realmpath' unknown (not found in config)");
                return $self->new_response(404 => 'I18N_OPENXPKI_UI_NO_SUCH_REALM_OR_SERVICE');
            }
        }

    # HOSTNAME mode
    } elsif ("hostname" eq $realm_mode) {
        my $host = $self->normalized_request_url->host // '';
        $self->log->debug("- looking for rule to match host '$host'");
        my $realm_map = $self->config->get_hash('realm.map');

        # TODO Remove legacy config support for host->realm map directly at webui.x.realm
        $realm_map //= $self->config->get_hash('realm');

        $self->log->trace('- realm map = ' . Dumper $realm_map ) if $self->log->is_trace;
        if (my ($pattern) = grep { $host =~ qr/\A$_\z/ } keys $realm_map->%*) {
            $self->log->debug("- match: pattern = $pattern") if $self->log->is_trace;
            $current_realm = $realm_map->{$pattern};
        }
        $self->log->warn("- unable to find matching realm for hostname '$host'") unless $current_realm;
    }

    if ($current_realm) {
        my ($realm, $stack) = split /\s*;\s*/, $current_realm;
        $self->log->debug("- detected realm: '$realm'");
        $self->current_realm($realm);
        if ($stack) {
            $self->log->debug("- detected fixed auth stack: '$stack'");
            $self->current_auth_stack($stack);
            # mark auth stack so it will be carried over in session renewals
            $self->session->param('is_fixed_auth_stack', 1);
        }
    }
}

# optionally called by OpenXPKI::Client::Service::Role::Base
sub cleanup ($self) {
    if ($self->has_session) {
        # write session changes to storage
        $self->session->flush;

    }
    # detach backend
    $self->client->detach if $self->has_client;
}

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers {
    return [
        'default' => sub ($self) {
            my $headers = $self->response->headers;
            # default security related headers, may be overwritten by config.
            # Also see https://owasp.org/www-project-secure-headers/ci/headers_add.json
            $headers->add('X-Content-Type-Options' => 'nosniff');
            $headers->strict_transport_security('max-age=31536000');
            $headers->content_security_policy(
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
            my $to_add = $self->config->get_hash('header');
            $headers->add($_ => $to_add->{$_}) for keys %$to_add;
            # default mime-type
            $headers->content_type('application/json');

            my $page = $self->handle_ui_request; # isa OpenXPKI::Client::Service::WebUI::Page
            $self->response->result($page);
            return $self->response;
        },
        'oidc_redirect' => sub ($self) {
            my $headers = $self->response->headers;
            $headers->add('X-Content-Type-Options' => 'nosniff');
            $headers->strict_transport_security('max-age=31536000');

            my $page = $self->handle_oidc;
            $self->response->result($page);
            return $self->response;
        },
    ];
}

# required by OpenXPKI::Client::Service::Role::Base
sub send_response ($self, $c, $response) {
    $c->set_response_headers($response);

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
    my $ui_resp = $self->ui_response; # OpenXPKI::Client::Service::WebUI::Response

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

    # Handle REDIRECT
    if ($action =~ /^redirect!(.+)/  || $page =~ /^redirect!(.+)/) {
        my $goto = $1;
        if ($goto =~ m{[^\w\-\!]}) {
            $goto = 'home';
            $self->log->warn("Invalid redirect target found - aborting");
        }
        $self->log->debug("Redirect to: $goto");
        my $page_obj = OpenXPKI::Client::Service::WebUI::Page->new(webui => $self);
        $page_obj->redirect->to($goto);
        return $page_obj;
    }

    # Handle LOGOUT / session restart
    # Do this before connecting the server to have the client in the
    # new session and to recover from backend session failure
    return $self->auth->logout($page) if $self->auth->is_logout($page);

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
        my $page_obj = OpenXPKI::Client::Service::WebUI::Page->new(webui => $self);
        $page_obj->status->error($page_obj->message_from_error_reply($reply));
        return $page_obj;
    }

    # Set pki_realm and auth_stack from auto-detection (URL path or hostname or
    # config) or previous session after logout
    $self->session->param('pki_realm', $self->current_realm) if $self->has_current_realm;
    $self->session->param('auth_stack', $self->current_auth_stack) if $self->has_current_auth_stack;

    # Handle BOOTSTRAP
    if ($page =~ /^bootstrap!(.+)/) {
        # Set logout menu for bootstrap page if we're not logged in (= not SERVICE_READY)
        if ($reply->{SERVICE_MSG} ne 'SERVICE_READY' and not defined $self->session->param('menu_items')) {
            my $reply = $self->client->send_receive_service_msg('GET_LOGOUT_MENU');
            if ($reply->{PARAMS} and my $menu = $reply->{PARAMS}->{main}) {
                $self->log->trace('Received logout menu = ' . Dumper $menu) if $self->log->is_trace;
                $self->session->param('menu_items', $menu);
            }
        }
        return $self->dispatcher->view($page);
    }

    # Handle PAGE or ACTION (if logged in = open channel)
    if ('SERVICE_READY' eq $reply->{SERVICE_MSG}) {
        return $self->dispatcher->dispatch($page || 'home', $action);

    # Handle LOGIN
    } else {
        # Prevent problems if the backend session logged out but did not terminate:
        # then the UI is logged in but backend is not.
        $self->logout_session if $self->session->param('is_logged_in');

        return $self->auth->login($page, $action, $reply);
    }
}

=head2 handle_oidc

Handles the OIDC authorization code callback from the Identity Provider.

Called when the IdP redirects the browser to C</webui/E<lt>realmE<gt>/oidc_redirect>.
The frontend session (incl. C<backend_session_id>, C<oidc-nonce>) has already been
restored from the JWT-encoded C<state> parameter by L</_build_session>.

Establishes the backend connection and calls L<OpenXPKI::Client::Service::WebUI::Auth/login>
directly with C<page='login'> to ensure the OIDC auth code (C<code> request
parameter) is processed — bypassing the redirect-to-login early return that would
happen with an empty page parameter.

This approach is robust to expired backend sessions: if the backend session timed
out during the IdP roundtrip, L<OpenXPKI::Client::Service::WebUI::Auth/login>
re-runs realm/stack selection using values from the restored frontend session and
eventually reaches C<GET_OIDC_LOGIN> again where the code exchange takes place.

Returns an instance of L<OpenXPKI::Client::Service::WebUI::Page>.

=cut
sub handle_oidc ($self) {
    $self->log->debug('Incoming OIDC redirect - processing auth code response');

    my $reply = $self->ping_client;

    if ($reply->{SERVICE_MSG} eq 'START_SESSION') {
        $reply = $self->client->init_session;
        $self->log->debug('Init new backend session for OIDC callback');
    }

    if ($reply->{SERVICE_MSG} eq 'ERROR') {
        my $page_obj = OpenXPKI::Client::Service::WebUI::Page->new(webui => $self);
        $page_obj->status->error($page_obj->message_from_error_reply($reply));
        return $page_obj;
    }

    # Propagate realm/stack from URL path detection into session so $self->auth->login()
    # can set them on a freshly created backend session if needed
    $self->session->param('pki_realm', $self->current_realm) if $self->has_current_realm;
    $self->session->param('auth_stack', $self->current_auth_stack) if $self->has_current_auth_stack;

    # Call login() with page='login' to reach the OIDC code-redemption branch.
    # Without this, an empty page parameter would trigger an early return (redirect
    # to login page) before the 'code' request parameter is ever examined.
    return $self->auth->login('login', undef, $reply);
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
    my $auth_stack = $self->session->param('auth_stack');
    my $is_fixed_auth_stack = $self->session->param('is_fixed_auth_stack');

    # create new session object but reuse old settings
    $self->session($self->session->clone);
    $self->session->param(pki_realm => $pki_realm) if $pki_realm;
    if ($auth_stack and $is_fixed_auth_stack) {
        $self->session->param(auth_stack => $auth_stack);
        $self->session->param(is_fixed_auth_stack => 1);
    }

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

        # Show message of the day if we have a page section (so it's not sent
        # in a request to !bootstrap or !redirect).
        # THIS WILL OVERWRITE ANY PREVIOUSLY SET STATUS.
        # FIXME Send MOTD with the bootstrap data and decide in Ember UI when and how to show (GH-958)
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

__PACKAGE__->meta->make_immutable;
