package OpenXPKI::Client::UI;
use Moose;

use English;

# Core modules
use Encode;
use Data::Dumper;
use MIME::Base64;
use Module::Load ();

# CPAN modules
use CGI::Session;
use URI::Escape;
use Log::Log4perl::MDC;
use Crypt::JWT qw( encode_jwt decode_jwt );
use Moose::Util::TypeConstraints qw( enum ); # PLEASE NOTE: this enables all warnings via Moose::Exporter
use Feature::Compat::Try;
use Type::Params qw( signature_for );

# Project modules
use OpenXPKI::Template;
use OpenXPKI::Client;
use OpenXPKI::Client::UI::Bootstrap;
use OpenXPKI::Client::UI::Login;

use experimental 'signatures'; # should be done after imports to safely disable warnings in Perl < 5.36

# ref to the cgi frontend session
has 'session' => (
    required => 1,
    is => 'rw',
    isa => 'CGI::Session|Undef',
);

# Response structure (JSON or some raw bytes) and HTTP headers
has 'resp' => (
    required => 1,
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response',
);

has 'realm_mode' => (
    required => 1,
    is => 'rw',
    isa => enum([qw(
        select
        path
        hostname
        fixed
    )]),
);

has 'realm_layout' => (
    required => 1,
    is => 'rw',
    isa => enum([qw(
        card
        list
    )]),
);

has 'socket_path' => (
    required => 1,
    is => 'ro',
    isa => 'Str',
);

has 'script_url' => (
    required => 1,
    is => 'ro',
    isa => 'Str',
);

has 'login_page' => (
    is => 'ro',
    isa => 'Str',
);

has 'login_url' => (
    is => 'ro',
    isa => 'Str',
);

has 'static_dir' => (
    is => 'ro',
    isa => 'Str',
);

# Only if realm_mode=path: a map of realms to URL paths
# {
#     realma => [
#         { url => 'realm-a', stack => 'LocalPassword' },
#         { url => 'realm-a-cert', stack => 'Certificate' },
#     ],
#     realmb => ...
# }
has 'realm_path_map' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

# the OXI::Client object
has 'backend' => (
    is => 'rw',
    isa => 'OpenXPKI::Client',
    lazy => 1,
    builder => '_init_backend',
    trigger => \&_init_backend,
);

# should be passed by the ui script to be shared, if not we create it
has 'log' => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    lazy => 1,
    default => sub{ return Log::Log4perl->get_logger( ); },
);

# holds key object to sign socket communication
has '_auth' => (
    is => 'ro',
    isa => 'Ref',
    init_arg => 'auth',
    predicate => 'has_auth',
);

=head2 _init_backend

Builder that creates an instance of OpenXPKI::Client and cares about
switching/creating the backend session

=cut
sub _init_backend {
    my $self = shift;
    # the trigger has the client as argument, the builder has not
    my $client = shift;

    if (!$client) {
        $client = OpenXPKI::Client->new({
            SOCKETFILE => $self->socket_path,
        });
        $self->log->debug('Create backend client instance');
    } else {
        $self->log->debug('Use provided client instance');
    }

    my $client_id = $client->get_session_id();
    my $session = $self->session();
    my $backend_id =  $session->param('backend_session_id') || undef;

    if ($backend_id and $client_id and $backend_id eq $client_id) {
        $self->log->debug('Backend session already loaded');
    } else {
        eval {
            $self->log->debug('First session reinit with id ' . ($backend_id || 'init'));
            $client->init_session({ SESSION_ID => $backend_id });
        };
        if (my $eval_err = $EVAL_ERROR) {
            my $exc = OpenXPKI::Exception->caught();
            if ($exc && $exc->message() eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
                $self->log->info('Backend session was gone - start a new one');
                # The session has gone - start a new one - might happen if the gui
                # was idle too long or the server was flushed
                $client->init_session({ SESSION_ID => undef });
                $self->resp->status->warn('I18N_OPENXPKI_UI_BACKEND_SESSION_GONE');
            } else {
                $self->log->error('Error creating backend session: ' . $eval_err->{message});
                $self->log->trace($eval_err);
                die "Backend communication problem";
            }
        }
        # refresh variable to current id
        $client_id = $client->get_session_id();
    }

    # logging stuff only
    if ($backend_id and $client_id eq $backend_id) {
        $self->log->info('Resume backend session with id ' . $client_id);
    } elsif ($backend_id) {
        $self->log->info('Re-Init backend session ' . $client_id . '/' . $backend_id );
    } else {
        $self->log->info('New backend session with id ' . $client_id);
    }
    $session->param('backend_session_id', $client_id);

    Log::Log4perl::MDC->put('ssid', substr($client_id,0,4));

    return $client;
}


sub BUILD {
    my $self = shift;

    if (!$self->session()->param('initialized')) {
        my $session = $self->session();
        $session->param('initialized', 1);
        $session->param('is_logged_in', 0);
        $session->param('user', undef);
    } elsif (my $user = $self->session()->param('user')) {
        Log::Log4perl::MDC->put('name', $user->{name});
        Log::Log4perl::MDC->put('role', $user->{role});
    } else {
        Log::Log4perl::MDC->put('name', undef);
        Log::Log4perl::MDC->put('role', undef);
    }

}

sub handle_request {

    my $self = shift;
    my $req = shift;
    my $cgi = $req->cgi();

    my $page = $req->param('page') || '';
    my $action = $self->__get_action($req);

    $self->log->debug('Incoming request: ' . join(', ', $page ? "page '$page'" : (), $action ? "action '$action'" : ()));

    # Check for goto redirection first
    if ($action =~ /^redirect!(.+)/  || $page =~ /^redirect!(.+)/) {
        my $goto = $1;
        if ($goto =~ m{[^\w\-\!]}) {
            $goto = 'home';
            $self->log->warn("Invalid redirect target found - aborting");
        }
        my $result = OpenXPKI::Client::UI::Result->new(
            client => $self,
            req => $req,
            resp => $self->resp,
        );
        $self->log->debug("Send redirect to $goto");
        $result->redirect->to($goto);
        return $result;
    }

    # Handle logout / session restart
    # Do this before connecting the server to have the client in the
    # new session and to recover from backend session failure
    if ($page eq 'logout' || $action eq 'logout') {

        # For SSO Logins the session might hold an external link
        # to logout from the SSO provider
        my $authinfo = $self->session()->param('authinfo') || {};
        my $redirectTo = $authinfo->{logout};

        # clear the session before redirecting to make sure we are safe
        $self->logout_session( $cgi );
        $self->log->info('Logout from session');

        # now perform the redirect if set
        if ($redirectTo) {
            $self->log->debug("External redirect on logout to " . $redirectTo);
            my $result = OpenXPKI::Client::UI::Result->new(
                client => $self,
                req => $req,
                resp => $self->resp,
            );
            $result->redirect->to($redirectTo);
            return $result;
        }

    }

    my $reply = $self->backend()->send_receive_service_msg('PING');
    my $status = $reply->{SERVICE_MSG};
    $self->log->trace('Ping replied ' . Dumper $reply) if $self->log->is_trace;
    $self->log->debug('current session status ' . $status);

    if ( $reply->{SERVICE_MSG} eq 'START_SESSION' ) {
        $reply = $self->backend()->init_session();
        $self->log->debug('Init new session');
        $self->log->trace('Init replied ' . Dumper $reply) if $self->log->is_trace;
    }

    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        my $result = OpenXPKI::Client::UI::Result->new(
            client => $self,
            req => $req,
            resp => $self->resp,
        );
        $self->log->debug("Got error from server");
        $result->set_status_from_error_reply($reply);
        return $result;
    }


    # Call to bootstrap components
    if ($page =~ /^bootstrap!(.+)/) {
        my $result = OpenXPKI::Client::UI::Bootstrap->new(
            client => $self,
            req => $req,
            resp => $self->resp,
        );
        $result->init_structure;
        return $result;
    }

    # Only handle requests if we have an open channel
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {
        return $self->handle_page( { req => $req, load_action => 1 } );
    }

    # if the backend session logged out but did not terminate
    # we get the problem that ui is logged in but backend is not
    $self->logout_session( $cgi ) if ($self->session()->param('is_logged_in'));

    # try to log in
    return $self->handle_login( { req => $req, reply => $reply } );

}

=head2 __load_class

Expect the page/action string and a reference to the cgi object
Extracts the expected class and method name and extra params encoded in
the given parameter and tries to instantiate the class. On success, the
class instance and the extracted method name is returned (two element
array). On error, both elements in the array are set to undef.

=cut

signature_for __load_class => (
    method => 1,
    named => [
        call => 'Str',
        req  => 'OpenXPKI::Client::UI::Request',
        is_action  => 'Bool', { default => 0 },
    ],
);
sub __load_class ($self, $arg) {

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
        my $decrypted = $arg->req->_decrypt_jwt($remainder) or return;
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
        $arg->req->add_secure_params($secure_params->%*);
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
            $arg->req->add_params($params->%*);
        }
    }

    $method  = 'index' unless $method;
    my $fullmethod = $arg->is_action ? "action_$method" : "init_$method";

    my @variants;
    # action!...
    if ($arg->is_action) {
        @variants = (
            sprintf("OpenXPKI::Client::UI::%s::Action::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::UI::%s::%s", ucfirst($class), $fullmethod),
            sprintf("OpenXPKI::Client::UI::%s::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::UI::%s::Action", ucfirst($class)),
            sprintf("OpenXPKI::Client::UI::%s", ucfirst($class)),
        );
    }
    # init!...
    else {
        @variants = (
            sprintf("OpenXPKI::Client::UI::%s::Init::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::UI::%s::%s", ucfirst($class), $fullmethod),
            sprintf("OpenXPKI::Client::UI::%s::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::UI::%s::Init", ucfirst($class)),
            sprintf("OpenXPKI::Client::UI::%s", ucfirst($class)),
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

        die "Package $pkg must inherit from OpenXPKI::Client::UI::Result"
            unless $pkg->isa('OpenXPKI::Client::UI::Result');

        my $obj = $pkg->new(
            client => $self,
            req => $arg->req,
            resp => $self->resp,
        );

        return ($obj, $fullmethod) if $obj->can($fullmethod);
    }

    $self->log->error(sprintf(
        'Could not find any handler class OpenXPKI::Client::UI::%s::* containing %s()',
        ucfirst($class),
        $fullmethod
    ));
    return;
}


=head2 __get_action

Expect a reference to the cgi object. Returns the value of
cgi->param('action') if set and the XSRFtoken is valid. If the token is
invalid, returns undef and sets the global status to error. If parameter
is empty or not set returns an empty string.

=cut

sub __get_action {

    my $self = shift;
    my $req = shift;

    my $rtoken_session = $self->session()->param('rtoken') || '';
    my $rtoken_request = $req->param('_rtoken') || '';
    # check XSRF token
    if ($req->param('action')) {
        if ($rtoken_request && ($rtoken_request eq $rtoken_session)) {
            $self->log->debug("Valid action request - returning " . $req->param('action'));
            return $req->param('action');

        # required to make the login page work when the session expires, #552
        } elsif( !$rtoken_session and ($req->param('action') =~ /^login\!/ )) {

            $self->log->debug("Login with expired session - ignoring rtoken");
            return $req->param('action');
        } else {

            $self->log->debug("Request with invalid rtoken ($rtoken_request != $rtoken_session)!");
            $self->resp->status->error('I18N_OPENXPKI_UI_REQUEST_TOKEN_NOT_VALID');
        }
    }
    return '';

}


sub __jwt_signature {

    my $self = shift;
    my $data = shift;
    my $jws = shift;

    return unless($self->has_auth());

    $self->log->debug('Sign data using key id ' . $jws->{keyid} );
    my $pkey = $self->_auth();
    return encode_jwt(payload => {
        param => $data,
        sid => $self->backend()->get_session_id(),
    }, key=> $pkey, auto_iat => 1, alg=>'ES256');

}

sub handle_page {

    my $self = shift;
    my $args = shift;

    my $req = $args->{req};
    # Set action or page - args always wins over CGI.
    # Action is only valid within a post request
    my $action = $args->{load_action} ? $self->__get_action($req) : '';
    my $page = (defined $args->{page} ? $args->{page} : $req->param('page')) || 'home';
    my @page_method_args;

    $self->log->trace('Handle page: ' . Dumper { map { $_ => $args->{$_} } grep { $_ ne 'req' } keys %$args } ) if $self->log->is_trace;

    my $result;
    my $redirected_from;
    if ($action) {
        $self->log->info('handle action ' . $action);

        my $method;
        ($result, $method) = $self->__load_class(call => $action, req => $req, is_action => 1);

        if ($result) {
            $self->log->debug("Calling method: $method()");
            $result->$method();
            # Follow an internal redirect to an init_* method
            if (my $target = $result->internal_redirect_target) {
                ($page, @page_method_args) = @$target;
                $redirected_from = $result;
                $self->log->trace("Internal redirect to: $page") if $self->log->is_trace;
            }
        } else {
            $self->resp->status->error('I18N_OPENXPKI_UI_ACTION_NOT_FOUND');
        }
    }

    # Render a page only if there is no action or object instantiation failed
    if (not $result or $redirected_from) {

        # Handling of special page requests - to be replaced by hash if it grows
        if ($page eq 'welcome') {
            $page = 'home!welcome';
        }

        my $method;
        if ($page) {
            ($result, $method) = $self->__load_class(call => $page, req => $req);
        }

        if ($result) {
            $self->log->debug("Calling method: $method()");
            $result->status($redirected_from->status) if $redirected_from;
            $result->$method(@page_method_args);
        } else {
            $result = OpenXPKI::Client::UI::Bootstrap->new(
                client => $self,
                req => $req,
                resp => $self->resp,
            );
            $result->init_error();
            $result->status->error('I18N_OPENXPKI_UI_PAGE_NOT_FOUND');
        }
    }

    Log::Log4perl::MDC->put('wfid', undef);

    return $result;

}

sub handle_login {

    my $self = shift;
    my $args = shift;

    my $req = $args->{req};
    my $cgi = $req->cgi();
    my $reply = $args->{reply};

    $reply = $self->backend->send_receive_service_msg('PING') if (!$reply);

    my $status = $reply->{SERVICE_MSG};

    my $uilogin = OpenXPKI::Client::UI::Login->new(
        client => $self,
        req => $req,
        resp => $self->resp,
    );

    # Login works in three steps realm -> auth stack -> credentials

    my $session = $self->session;
    my $page = $req->param('page') || '';

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
    my $action = $self->__get_action($req);

    $self->log->info("Not logged in. Doing auth. page = '$page', action = '$action'");

    # Special handling for pki_realm and stack params
    if ($action eq 'login!realm' && $req->param('pki_realm')) {
        $session->param('pki_realm', scalar $req->param('pki_realm'));
        $session->param('auth_stack', undef);
        $self->log->debug('set realm in session: ' . $req->param('pki_realm') );
    }
    if($action eq 'login!stack' && $req->param('auth_stack')) {
        $session->param('auth_stack', scalar $req->param('auth_stack'));
        $self->log->debug('set auth_stack in session: ' . $req->param('auth_stack') );
    }

    # ENV always overrides session, keep this after the above block to prevent
    # people from hacking into the session parameters
    if ($ENV{OPENXPKI_PKI_REALM}) {
        $session->param('pki_realm', $ENV{OPENXPKI_PKI_REALM});
    }
    if ($ENV{OPENXPKI_AUTH_STACK}) {
        $session->param('auth_stack', $ENV{OPENXPKI_AUTH_STACK});
    }

    my $pki_realm = $session->param('pki_realm') || '';
    my $auth_stack =  $session->param('auth_stack') || '';

    # if this is an initial request, force redirect to the login page
    # will do an external redirect in case loginurl is set in config
    if ($action !~ /^login/ && $page !~ /^login/) {
        # Requests to pages can be redirected after login, store page in session
        if ($page && $page ne 'logout' && $page ne 'welcome') {
            $self->log->debug("Store page request for later redirect " . $page);
            $self->session()->param('redirect', $page);
        }

        # Link to an internal method using the class!method
        if (my $loginpage = $self->login_page) {

            # internal call to handle_page
            return $self->handle_page({ page => $loginpage, req => $req });

        } elsif (my $loginurl = $self->login_url) {

            $self->log->debug("Redirect to external login page " . $loginurl );
            $uilogin->redirect->external($loginurl);
            return $uilogin;

        } elsif ( $cgi->http('HTTP_X-OPENXPKI-Client') ) {

            # Session is gone but we are still in the ember application
            $uilogin->redirect->to('login');

        } else {

            # This is not an ember request so we need to redirect
            # back to the ember page - try if the session has a baseurl
            my $url = $self->session()->param('baseurl');
            # if not, get the path from the referer
            if (!$url && (($ENV{HTTP_REFERER}//'') =~ m{https?://[^/]+(/[\w/]*[\w])/?}i)) {
                $url = $1;
                $self->log->debug('Restore redirect from referer');
            }
            $url .= '/#/openxpki/login';
            $self->log->debug('Redirect to login page: ' . $url);
            $uilogin->redirect->to($url);
        }
    }

    if ( $status eq 'GET_PKI_REALM' ) {
        $self->log->debug("Status: '$status'");
        # realm set
        if ($pki_realm) {
            $reply = $self->backend()->send_receive_service_msg( 'GET_PKI_REALM', { PKI_REALM => $pki_realm, } );
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
            $reply = $self->backend()->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', {
               AUTHENTICATION_STACK => $auth_stack
            });
            $status = $reply->{SERVICE_MSG};
        } else {
            my $stacks = $reply->{'PARAMS'}->{'AUTHENTICATION_STACKS'};

            # List stacks and hide those starting with an underscore
            my @stack_list = map {
                ($stacks->{$_}->{name} !~ /^_/) ? ($_ = {
                    'value' => $stacks->{$_}->{name},
                    'label' => $stacks->{$_}->{label},
                    'description' => $stacks->{$_}->{description}
                }) : ()
            } keys %{$stacks};

            # Directly load stack if there is only one
            if (scalar @stack_list == 1)  {
                $auth_stack = $stack_list[0]->{value};
                $session->param('auth_stack', $auth_stack);
                $self->log->debug("Only one stack avail ($auth_stack) - autoselect");
                $reply = $self->backend()->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', {
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
                    next unless defined ($ENV{$envkey});
                    $data->{$key} = Encode::decode('UTF-8', $ENV{$envkey}, Encode::LEAVE_SRC | Encode::FB_CROAK);
                }
            # legacy support
            } elsif (my $user = $ENV{'OPENXPKI_USER'} || $ENV{'REMOTE_USER'} || '') {
                $data->{username} = $user;
                $data->{role} = $ENV{'OPENXPKI_GROUP'} if($ENV{'OPENXPKI_GROUP'});
            }

            # at least some items were found so we send them to the backend
            if ($data) {
                $self->log->trace('Sending auth data ' . Dumper $data) if $self->log->is_trace;

                $data = $self->__jwt_signature($data, $jws) if ($jws);

                $reply = $self->backend()->send_receive_service_msg( 'GET_CLIENT_LOGIN', $data );

            # as nothing was found we do not even try to login in and look for a redirect
            } elsif (my $loginurl = $auth->{login}) {

                # the login url might contain a backlink to the running instance
                $loginurl = OpenXPKI::Template->new->render( $loginurl,
                    { baseurl => $session->param('baseurl') } );

                $self->log->debug("No auth data in environment - redirect found $loginurl");
                $uilogin->redirect->external($loginurl);
                return $uilogin;

            # bad luck - something seems to be really wrong
            } else {
                $self->log->error('No ENV data to perform SSO Login');
                $self->logout_session( $cgi );
                $uilogin->init_login_missing_data();
                return $uilogin;
            }

        } elsif ( $login_type eq 'X509' ) {
            my $user = $ENV{'SSL_CLIENT_S_DN_CN'} || $ENV{'SSL_CLIENT_S_DN'};
            my $cert = $ENV{'SSL_CLIENT_CERT'} || '';

            $self->log->trace('ENV is ' . Dumper \%ENV) if $self->log->is_trace;

            if ($cert) {
                $self->log->info('Sending X509 Login ( '.$user.' )');
                my @chain;
                # larger chains are very unlikely and we dont support stupid clients
                for (my $cc=0;$cc<=3;$cc++)   {
                    my $chaincert = $ENV{'SSL_CLIENT_CERT_CHAIN_'.$cc};
                    last unless ($chaincert);
                    push @chain, $chaincert;
                }

                my $data = { certificate => $cert, chain => \@chain };
                $data = $self->__jwt_signature($data, $jws) if ($jws);

                $reply =  $self->backend()->send_receive_service_msg( 'GET_X509_LOGIN', $data);
                $self->log->trace('Auth result ' . Dumper $reply) if $self->log->is_trace;
            } else {
                $self->log->error('Certificate missing for X509 Login');
                $self->logout_session( $cgi );
                $uilogin->init_login_missing_data;
                return $uilogin;
            }

        } elsif( $login_type  eq 'PASSWD' ) {

            # form send / credentials are passed (works with an empty form too...)

            if (($self->__get_action($req)) eq 'login!password') {
                $self->log->debug('Seems to be an auth try - validating');
                ##FIXME - Input validation

                my $data;
                my @fields = $auth->{field} ?
                    (map { $_->{name} } @{$auth->{field}}) :
                    ('username','password');

                foreach my $field (@fields) {
                    my $val = $req->param($field);
                    next unless ($val);
                    $data->{$field} = $val;
                }

                $data = $self->__jwt_signature($data, $jws) if ($jws);

                $reply = $self->backend()->send_receive_service_msg( 'GET_PASSWD_LOGIN', $data );
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
        $reply = $self->backend()->send_receive_service_msg( 'COMMAND',
            { COMMAND => 'get_session_info', PARAMS => {}, API => 2 } );

        if ( $reply->{SERVICE_MSG} eq 'COMMAND' ) {

            my $session_info = $reply->{PARAMS};

            # merge baseurl to authinfo links
            # (we need to get the baseurl before recreating the session below)
            my $auth_info = {};
            my $baseurl = $session->param('baseurl');
            if (my $ai = $session_info->{authinfo}) {
                my $tt = OpenXPKI::Template->new;
                for my $key (keys %{$ai}) {
                    $auth_info->{$key} = $tt->render( $ai->{$key}, { baseurl => $baseurl } );
                }
            }
            delete $session_info->{authinfo};

            #$self->backend()->rekey_session();
            #my $new_backend_session_id = $self->backend()->get_session_id();

            # Generate a new frontend session to prevent session fixation
            # The backend session remains the same but can not be used by an
            # adversary as the id is never exposed and we destroy the old frontend
            # session so access to the old session is not possible
            $self->_recreate_frontend_session($session, $session_info, $auth_info);

            Log::Log4perl::MDC->put('sid', substr($session->id,0,4));

            $self->resp->session_cookie->id($session->id);

            if ($auth_info->{login}) {
                $uilogin->redirect->to($auth_info->{login});
            } else {
                $uilogin->init_index();
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

sub _recreate_frontend_session {

    my $self = shift;
    my $session = shift;
    my $data = shift;
    my $auth_info = shift;

    $self->log->trace('Got session info: '. Dumper $data) if $self->log->is_trace;

    # fetch redirect from old session before deleting it!
    my $redirect = $session->param('redirect');

    # delete the old instance data
    $session->delete;
    $session->flush;
    # call new on the existing session object to reuse settings
    $session = $session->new;

    $self->log->debug('New frontend session id : '. $session->id );

    if ($redirect) {
        $self->log->trace('Carry over redirect target ' . $redirect);
        $session->param('redirect', $redirect);
    }

    # set some data
    $session->param('backend_session_id', $self->backend->get_session_id );

    # move userinfo to own node
    $session->param('userinfo', $data->{userinfo} || {});
    delete $data->{userinfo};

    $session->param('authinfo', $auth_info);

    $session->param('user', $data);
    $session->param('pki_realm', $data->{pki_realm});
    $session->param('is_logged_in', 1);
    $session->param('initialized', 1);

    $self->session($session);

    # Check for MOTD
    my $motd = $self->backend->send_receive_command_msg( 'get_motd' );
    if (ref $motd->{PARAMS} eq 'HASH') {
        $self->log->trace('Got MOTD: '. Dumper $motd->{PARAMS} ) if $self->log->is_trace;
        $session->param('motd', $motd->{PARAMS} );
    }

    # menu
    my $reply = $self->backend->send_receive_command_msg( 'get_menu' );
    $self->_set_menu($session, $reply->{PARAMS}) if $reply->{PARAMS};

    $session->flush;

}

sub _set_menu {
    my $self = shift;
    my $session = shift;
    my $menu = shift;

    $self->log->trace('Menu ' . Dumper $menu) if $self->log->is_trace;

    $session->param('menu_items', $menu->{main} || []);

    # persist the optional parts of the menu hash (landmark, tasklist, search attribs)
    $session->param('landmark', $menu->{landmark} || {});
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
        $session->param('ping', $ping);
    }

    # tasklist, wfsearch, certsearch and bulk can have multiple branches
    # using named keys. We try to autodetect legacy formats and map
    # those to a "default" key
    # TODO Remove legacy compatibility

    # config items are a list of hashes
    foreach my $key (qw(tasklist bulk)) {

        if (ref $menu->{$key} eq 'ARRAY') {
            $session->param($key, { 'default' => $menu->{$key} });
        } elsif (ref $menu->{$key} eq 'HASH') {
            $session->param($key, $menu->{$key} );
        } else {
            $session->param($key, { 'default' => [] });
        }
        $self->log->trace("Got $key: " . Dumper $menu->{$key}) if $self->log->is_trace;
    }

    # top level is a hash that must have a "attributes" node
    # legacy format was a single list of attributes
    # TODO Remove legacy compatibility
    foreach my $key (qw(wfsearch certsearch)) {

        # plain attributes
        if (ref $menu->{$key} eq 'ARRAY') {
            $session->param($key, { 'default' => { attributes => $menu->{$key} } } );
        } elsif (ref $menu->{$key} eq 'HASH') {
            $session->param($key, $menu->{$key} );
        } else {
            # empty hash is used to disable the search page
            $session->param($key, {} );
        }
        $self->log->trace("Got $key: " . Dumper $menu->{$key}) if $self->log->is_trace;
    }

    foreach my $key (qw(datapool)) {
        if (ref $menu->{$key} eq 'HASH' and $menu->{$key}->{default}) {
            $session->param($key, $menu->{$key} );
        } else {
            $session->param($key, { default => {} });
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
    $session->param('certdetails', $certdetails);

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
    $session->param('wfdetails', $wfdetails);
}

=head2 logout_session

Delete and flush the current session and recreate a new one using
the remaining class object. If the internal session handler is used,
the session is cleared but not destreoyed.

If you pass a reference to the CGI handler, the session cookie is updated.
=cut

sub logout_session {

    my $self = shift;
    my $cgi = shift;

    $self->log->info("session logout");

    my $session = $self->session;
    $self->backend->logout;
    $self->session->delete;
    $self->session->flush;
    $self->session($self->session->new);

    Log::Log4perl::MDC->put('sid', substr($self->session->id,0,4));

    # flush the session cookie
    $self->resp->session_cookie->id($self->session->id);

}

__PACKAGE__->meta->make_immutable;
