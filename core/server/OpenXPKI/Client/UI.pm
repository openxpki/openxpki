package OpenXPKI::Client::UI;
use Moose;

use English;

# Core modules
use Encode;
use Data::Dumper;
use MIME::Base64;

# CPAN modules
use CGI::Session;
use URI::Escape;
use Log::Log4perl::MDC;
use Crypt::JWT qw(encode_jwt);

# Project modules
use OpenXPKI::Template;
use OpenXPKI::Client;
use OpenXPKI::i18n qw( i18nGettext );
use OpenXPKI::Client::UI::Bootstrap;
use OpenXPKI::Client::UI::Login;

# ref to the cgi frontend session
has 'session' => (
    required => 1,
    is => 'rw',
    isa => 'CGI::Session|Undef',
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
has 'logger' => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    lazy => 1,
    default => sub{ return Log::Log4perl->get_logger( ); },
);

has '_config' => (
    required => 1,
    is => 'ro',
    isa => 'HashRef',
    init_arg => 'config',
);

# holds key object to sign socket communication
has '_auth' => (
    is => 'ro',
    isa => 'Ref',
    init_arg => 'auth',
    predicate => 'has_auth',
);

# Hold warnings from init
has _status => (
    is => 'rw',
    isa => 'HashRef|Undef',
    lazy => 1,
    default => undef
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
            SOCKETFILE => $self->_config()->{'socket'},
        });
        $self->logger()->debug('Create backend client instance');
    } else {
        $self->logger()->debug('Use provided client instance');
    }

    my $client_id = $client->get_session_id();
    my $session = $self->session();
    my $backend_id =  $session->param('backend_session_id') || undef;

    if ($backend_id and $client_id and $backend_id eq $client_id) {
        $self->logger()->debug('Backend session already loaded');
    } else {
        eval {
            $self->logger()->debug('First session reinit with id ' . ($backend_id || 'init'));
            $client->init_session({ SESSION_ID => $backend_id });
        };
        if (my $eval_err = $EVAL_ERROR) {
            my $exc = OpenXPKI::Exception->caught();
            if ($exc && $exc->message() eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
                $self->logger()->info('Backend session was gone - start a new one');
                # The session has gone - start a new one - might happen if the gui
                # was idle too long or the server was flushed
                $client->init_session({ SESSION_ID => undef });
                $self->_status({ level => 'warn', message => i18nGettext('I18N_OPENXPKI_UI_BACKEND_SESSION_GONE')});
            } else {
                $self->logger()->error('Error creating backend session: ' . $eval_err->{message});
                $self->logger()->trace($eval_err);
                die "Backend communication problem";
            }
        }
        # refresh variable to current id
        $client_id = $client->get_session_id();
    }

    # logging stuff only
    if ($backend_id and $client_id eq $backend_id) {
        $self->logger()->info('Resume backend session with id ' . $client_id);
    } elsif ($backend_id) {
        $self->logger()->info('Re-Init backend session ' . $client_id . '/' . $backend_id );
    } else {
        $self->logger()->info('New backend session with id ' . $client_id);
    }
    $session->param('backend_session_id', $client_id);

    Log::Log4perl::MDC->put('ssid', substr($client_id,0,4));

    $self->logger()->trace( Dumper $session->dataref ) if $self->logger->is_trace;
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
    my $action = $self->__get_action( $req ) || '';

    $self->logger()->debug('Incoming request: ' . join(', ', $page ? "page '$page'" : (), $action ? "action '$action'" : ()));

    # Check for goto redirection first
    if ($action =~ /^redirect!(.+)/  || $page =~ /^redirect!(.+)/) {
        my $goto = $1;
        my $result = OpenXPKI::Client::UI::Result->new({ client => $self, req => $req });
        $self->logger()->debug("Send redirect to $goto");
        $result->redirect( $goto );
        return $result->render();
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
        $self->logger()->info('Logout from session');

        # now perform the redirect if set
        if ($redirectTo) {
            $self->logger()->debug("External redirect on logout to " . $redirectTo);
            my $result = OpenXPKI::Client::UI::Result->new({ client => $self, req => $req });
            $result->redirect( $redirectTo );
            return $result->render();
        }

    }

    my $reply = $self->backend()->send_receive_service_msg('PING');
    my $status = $reply->{SERVICE_MSG};
    $self->logger()->trace('Ping replied ' . Dumper $reply) if $self->logger->is_trace;
    $self->logger()->debug('current session status ' . $status);

    if ( $reply->{SERVICE_MSG} eq 'START_SESSION' ) {
        $reply = $self->backend()->init_session();
        $self->logger()->debug('Init new session');
        $self->logger()->trace('Init replied ' . Dumper $reply) if $self->logger->is_trace;
    }

    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        my $result = OpenXPKI::Client::UI::Result->new({ client => $self, req => $req });
        $self->logger()->debug("Got error from server");
        return $result->set_status_from_error_reply( $reply );
    }


    # Call to bootstrap components
    if ($page =~ /^bootstrap!(.+)/) {
        my $result = OpenXPKI::Client::UI::Bootstrap->new({ client => $self, req => $req });
        return $result->init_structure( )->render();
    }

    # Only handle requests if we have an open channel
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {
        return $self->handle_page( { req => $req } );
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

sub __load_class {

    my $self = shift;
    my $call = shift;
    my $req = shift;

    $self->logger()->debug("Incoming call to load_class $call");

    my ($class, $method, $param) = ($call =~ /\A (\w+)\!? (\w+)? \!?(.*) \z/xms);

    if (!$class) {
        $self->logger()->error("Failed to parse page load string $call");
        return (undef, undef);
    }

    $method  = 'index' if (!$method );

    my %extra;
    if ($param) {
        my @extra = split /!/, $param;
        while (my $key = shift @extra) {
            my $val = shift @extra // '';
            $extra{$key} = Encode::decode("UTF-8", uri_unescape($val));
        }
        $self->logger()->trace("Found extra params " . Dumper \%extra ) if $self->logger->is_trace;
    }

    $self->logger()->debug("Loading handler class $class");

    $class = "OpenXPKI::Client::UI::".ucfirst($class);
    eval "use $class;1";
    if ($EVAL_ERROR) {
        $self->logger()->error("Failed loading handler class $class: $EVAL_ERROR");
        return (undef, undef);
    }

    my $result = $class->new({ client => $self, req => $req, extra => \%extra });

    return ($result, $method);

}


=head2 __get_action

Expect a reference to the cgi object. Returns the value of
cgi->param('action') if set and the XSRFtoken is valid. If the token is
invalid, returns undef and sets the global status to error. If parameter
is empty or not set returns undef.

=cut

sub __get_action {

    my $self = shift;
    my $req = shift;

    my $rtoken_session = $self->session()->param('rtoken') || '';
    my $rtoken_request = $req->param('_rtoken') || '';
    # check XSRF token
    if ($req->param('action')) {
        if ($rtoken_request && ($rtoken_request eq $rtoken_session)) {
            $self->logger()->debug("Valid action request - returning " . $req->param('action'));
            return $req->param('action');

        # required to make the login page work when the session expires, #552
        } elsif( !$rtoken_session and ($req->param('action') =~ /^login\!/ )) {

            $self->logger()->debug("Login with expired session - ignoring rtoken");
            return $req->param('action');
        } else {

            $self->logger()->debug("Request with invalid rtoken ($rtoken_request != $rtoken_session)!");
            $self->_status({ level => 'error', 'message' => i18nGettext('I18N_OPENXPKI_UI_REQUEST_TOKEN_NOT_VALID')});
        }
    }
    return;

}


sub __jwt_signature {

    my $self = shift;
    my $data = shift;
    my $jws = shift;

    return unless($self->has_auth());

    $self->logger()->debug('Sign data using key id ' . $jws->{keyid} );
    my $pkey = $self->_auth();
    return encode_jwt(payload => {
        param => $data,
        sid => $self->backend()->get_session_id(),
    }, key=> $pkey, auto_iat => 1, alg=>'ES256');

}

sub handle_page {

    my $self = shift;
    my $args = shift;
    my $method_args = shift || {};

    my $req = $args->{req};
    my $cgi = $req->cgi();

    # set action and page - args always wins about cgi

    my $result;
    my $action = '';
    # action is only valid explicit or within a post request
    if (defined $args->{action}) {
       $action = $args->{action};
    } else {
        $action = $self->__get_action( $req );
    }

    $self->logger()->trace('Handle page: ' . Dumper { map { $_ => $args->{$_} } grep { $_ ne 'req' } keys %$args } ) if $self->logger->is_trace;

    my $page = (defined $args->{page} ? $args->{page} : $req->param('page')) || 'home';

    if ($action) {
        $self->logger()->info('handle action ' . $action);

        my $method;
        ($result, $method) = $self->__load_class( $action, $req );

        if ($result) {
            $method  = "action_$method";
            $self->logger()->debug("Method is $method");
            $result->$method( $method_args );
        } else {
            $self->_status({ level => 'error', 'message' => i18nGettext('I18N_OPENXPKI_UI_ACTION_NOT_FOUND')});
        }
    }

    # Render a page only if there is no action result
    if (!$result) {

        # Handling of special page requests - to be replaced by hash if it grows
        if ($page eq 'welcome') {
            $page = 'home!welcome';
        }

        my $method;
        if ($page) {
            ($result, $method) = $self->__load_class( $page, $req );
        }

        if (!$result) {
            $self->logger()->error("Failed loading page class");
            $result = OpenXPKI::Client::UI::Bootstrap->new({ client => $self,  cgi => $cgi });
            $result->init_error();
            $result->set_status(i18nGettext('I18N_OPENXPKI_UI_PAGE_NOT_FOUND'),'error');

        } else {
            $method  = "init_$method";
            $self->logger()->debug("Method is $method");
            $result->$method( $method_args );
        }
    }

    Log::Log4perl::MDC->put('wfid', undef);

    return $result->render();

}

sub handle_login {

    my $self = shift;
    my $args = shift;

    my $req = $args->{req};
    my $cgi = $req->cgi();
    my $reply = $args->{reply};

    $reply = $self->backend()->send_receive_service_msg('PING') if (!$reply);

    my $status = $reply->{SERVICE_MSG};

    my $result = OpenXPKI::Client::UI::Login->new({ client => $self, req => $req });

    # Login works in three steps realm -> auth stack -> credentials

    my $session = $self->session();
    my $page = $req->param('page') || '';

    # this is the incoming logout action
    if ($page eq 'logout') {
        $result->redirect( { goto => 'login!logout' } );
        return $result->render();
    }

    # this is the redirect to the "you have been logged out page"
    if ($page eq 'login!logout') {
        return $result->init_logout()->render();
    }

    # action is only valid within a post request
    my $action = $self->__get_action( $req ) || '';

    $self->logger()->info('not logged in - doing auth - page is '.$page.' - action is ' . $action);

    # Special handling for pki_realm and stack params
    if ($action eq 'login!realm' && $req->param('pki_realm')) {
        $session->param('pki_realm', scalar $req->param('pki_realm'));
        $session->param('auth_stack', undef);
        $self->logger()->debug('set realm in session: ' . $req->param('pki_realm') );
    }
    if($action eq 'login!stack' && $req->param('auth_stack')) {
        $session->param('auth_stack', scalar $req->param('auth_stack'));
        $self->logger()->debug('set auth_stack in session: ' . $req->param('auth_stack') );
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
            $self->logger()->debug("Store page request for later redirect " . $page);
            $self->session()->param('redirect', $page);
        }

        # Link to an internal method using the class!method
        if (my $loginpage = $self->_config()->{loginpage}) {

            # internal call to handle_page
            return $self->handle_page({ action => '', page => $loginpage, req => $req });

        } elsif (my $loginurl = $self->_config()->{loginurl}) {

            $self->logger()->debug("Redirect to external login page " . $loginurl );
            $result->redirect( { goto => $loginurl, type => 'external' } );
            return $result->render();
            # Do a real exit to skip the error handling of the script body
            exit;

        } elsif ( $cgi->http('HTTP_X-OPENXPKI-Client') ) {

            # Session is gone but we are still in the ember application
            $result->redirect('login');

        } else {

            # This is not an ember request so we need to redirect
            # back to the ember page - try if the session has a baseurl
            my $url = $self->session()->param('baseurl');
            # if not, get the path from the referer
            if (!$url && ($ENV{HTTP_REFERER} =~ m{https?://[^/]+(/[\w/]*[\w])/?}i)) {
                $url = $1;
                $self->logger()->debug('Restore redirect from referer');
            }
            $url .= '/#/openxpki/login';
            $self->logger()->debug('Redirect to login page: ' . $url);
            $result->redirect($url);
        }
    }

    if ( $status eq 'GET_PKI_REALM' ) {
        if ($pki_realm) {
            $reply = $self->backend()->send_receive_service_msg( 'GET_PKI_REALM', { PKI_REALM => $pki_realm, } );
            $status = $reply->{SERVICE_MSG};
            $self->logger()->debug("Selected realm $pki_realm, new status " . $status);
        } else {
            my $realms = $reply->{'PARAMS'}->{'PKI_REALMS'};
            my @realm_list = map { $_ = {'value' => $realms->{$_}->{NAME}, 'label' => i18nGettext($realms->{$_}->{DESCRIPTION})} } keys %{$realms};
            $self->logger()->trace("Offering realms: " . Dumper \@realm_list ) if $self->logger->is_trace;
            return $result->init_realm_select( \@realm_list  )->render();
        }
    }

    if ( $status eq 'GET_AUTHENTICATION_STACK' ) {
        # Never auth with an internal stack!
        if ( $auth_stack && $auth_stack !~ /^_/) {
            $self->logger()->debug("Authentication stack: $auth_stack");
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
                    'label' => i18nGettext($stacks->{$_}->{label}),
                    'description' => $stacks->{$_}->{description}
                }) : ()
            } keys %{$stacks};

            # Directly load stack if there is only one
            if (scalar @stack_list == 1)  {
                $auth_stack = $stack_list[0]->{value};
                $session->param('auth_stack', $auth_stack);
                $self->logger()->debug("Only one stack avail ($auth_stack) - autoselect");
                $reply = $self->backend()->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', {
                    AUTHENTICATION_STACK => $auth_stack
                } );
                $status = $reply->{SERVICE_MSG};
            } else {
                $self->logger()->trace("Offering stacks: " . Dumper \@stack_list ) if $self->logger->is_trace;
                return $result->init_auth_stack( \@stack_list )->render();
            }
        }
    }

    $self->logger()->debug("Selected realm $pki_realm, new status " . $status);
    $self->logger()->trace('Reply: ' . Dumper $reply) if $self->logger->is_trace;

    # we have more than one login handler and leave it to the login
    # class to render it right.
    if ( $status =~ /GET_(.*)_LOGIN/ ) {
        my $login_type = $1;

        ## FIXME - need a good way to configure login handlers
        $self->logger()->info('Requested login type ' . $login_type );
        my $auth = $reply->{PARAMS};
        my $jws = $reply->{SIGN};

        # SSO Login uses data from the ENV, so no need to render anything
        if ( $login_type eq 'CLIENT' ) {

            $self->logger()->trace('ENV is ' . Dumper \%ENV) if $self->logger->is_trace;
            my $data;
            if ($auth->{envkeys}) {
                foreach my $key (keys %{$auth->{envkeys}}) {
                    my $envkey = $auth->{envkeys}->{$key};
                    $self->logger()->debug("Try to load $key from $envkey");
                    next unless defined ($ENV{$envkey});
                    $data->{$key} = $ENV{$envkey};
                }
            # legacy support
            } elsif (my $user = $ENV{'OPENXPKI_USER'} || $ENV{'REMOTE_USER'} || '') {
                $data->{username} = $user;
                $data->{role} = $ENV{'OPENXPKI_GROUP'} if($ENV{'OPENXPKI_GROUP'});
            }

            # at least some items were found so we send them to the backend
            if ($data) {
                $self->logger()->trace('Sending auth data ' . Dumper $data) if $self->logger->is_trace;

                $data = $self->__jwt_signature($data, $jws) if ($jws);

                $reply = $self->backend()->send_receive_service_msg( 'GET_CLIENT_LOGIN', $data );

            # as nothing was found we do not even try to login in and look for a redirect
            } elsif (my $loginurl = $auth->{login}) {

                # the login url might contain a backlink to the running instance
                $loginurl = OpenXPKI::Template->new()->render( $loginurl,
                    { baseurl => $session->param('baseurl') } );

                $self->logger()->debug("No auth data in environment - redirect found $loginurl");
                $result->redirect( { goto => $loginurl, type => 'external' } );
                return $result->render();

            # bad luck - something seems to be really wrong
            } else {
                $self->logger()->error('No ENV data to perform SSO Login');
                $self->logout_session( $cgi );
                return $result->init_login_missing_data()->render();
            }

        } elsif ( $login_type eq 'X509' ) {
            my $user = $ENV{'SSL_CLIENT_S_DN_CN'} || $ENV{'SSL_CLIENT_S_DN'};
            my $cert = $ENV{'SSL_CLIENT_CERT'} || '';

            $self->logger()->trace('ENV is ' . Dumper \%ENV) if $self->logger->is_trace;

            if ($cert) {
                $self->logger()->info('Sending X509 Login ( '.$user.' )');
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
                $self->logger()->trace('Auth result ' . Dumper $reply) if $self->logger->is_trace;
            } else {
                $self->logger()->error('Certificate missing for X509 Login');
                $self->logout_session( $cgi );
                return $result->init_login_missing_data()->render();
            }

        } elsif( $login_type  eq 'PASSWD' ) {

            # form send / credentials are passed (works with an empty form too...)

            if (($self->__get_action($req) || '') eq 'login!password') {
                $self->logger()->debug('Seems to be an auth try - validating');
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
                $self->logger()->trace('Auth result ' . Dumper $reply) if $self->logger->is_trace;

            } else {
                $self->logger()->debug('No credentials, render form');
                return $result->init_login_passwd($auth)->render();
            }

        } else {

            $self->logger()->warn('Unknown login type ' . $login_type );
        }
    }

    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {
        $self->logger()->info('Authentication successul - fetch session info');
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

            # FIXME Remove direct access to $main::cookie and main::encrypt_cookie
            if ($main::cookie) {
                $main::cookie->{'-value'} = main::encrypt_cookie($session->id);
                push @main::header, ('-cookie', $cgi->cookie( $main::cookie ));
            }
            $self->logger->trace('CGI Header ' . Dumper \@main::header ) if $self->logger->is_trace;

            if ($auth_info->{login}) {
                $result->redirect( $auth_info->{login} );
            } else {
                $result->init_index();
            }
            return $result->render();
        }
    }

    if ( $reply->{SERVICE_MSG} eq 'ERROR') {

        $self->logger()->trace('Server Error Msg: '. Dumper $reply) if $self->logger->is_trace;

        # Failure here is likely a wrong password

        if ($reply->{'ERROR'} && $reply->{'ERROR'}->{CLASS} eq 'OpenXPKI::Exception::Authentication') {
            $result->set_status(i18nGettext( $reply->{'ERROR'}->{LABEL} ),'error');
        } else {
            $result->set_status_from_error_reply($reply);
        }
        return $result->render();
    }

    $self->logger()->debug("unhandled error during auth");
    return;

}

sub _recreate_frontend_session() {

    my $self = shift;
    my $session = shift;
    my $data = shift;
    my $auth_info = shift;

    # fetch redirect from old session before deleting it!
    my $redirect = $session->param('redirect');

    # delete the old instance data
    $session->delete;
    $session->flush;
    # call new on the existing session object to reuse settings
    $session = $session->new;

    $self->logger->debug('New frontend session id : '. $session->id );

    if ($redirect) {
        $self->logger->trace('Carry over redirect target ' . $redirect);
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
        $self->logger->trace('Got MOTD: '. Dumper $motd->{PARAMS} ) if $self->logger->is_trace;
        $session->param('motd', $motd->{PARAMS} );
    }

    $self->logger->trace('Got session info: '. Dumper $data) if $self->logger->is_trace;

    $session->flush;

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

    $self->logger()->info("session logout");

    my $session = $self->session();
    $self->backend()->logout();
    $self->session()->delete();
    $self->session()->flush();
    $self->session( $self->session()->new() );

    Log::Log4perl::MDC->put('sid', substr($self->session->id,0,4));

    # flush the session cookie
    if ($cgi && $main::cookie) {
        $main::cookie->{'-value'} = main::encrypt_cookie($self->session->id);
        push @main::header, ('-cookie', $cgi->cookie( $main::cookie ));
    }

}


1;
