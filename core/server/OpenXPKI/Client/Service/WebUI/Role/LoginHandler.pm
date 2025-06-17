package OpenXPKI::Client::Service::WebUI::Role::LoginHandler;
use OpenXPKI -role;
use namespace::autoclean;

requires qw(
    log
    config
    session
    request
    client
    realm_mode
    auth
    has_auth
    current_realm
    is_realm_selection_page

    url_path_for
    param
    handle_view
    logout_session
    new_frontend_session
    ping_client
);

# Core modules
use Encode;
use MIME::Base64 qw( encode_base64 );

# CPAN modules
use Crypt::JWT qw( encode_jwt decode_jwt );

# Project modules
use OpenXPKI::Client::Service::WebUI::Page::Login;
use OpenXPKI::Template;
use OpenXPKI::Dumper;


has login_page => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->get('login.page') || $self->config->get('global.loginpage') // '' },
);

has login_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->get('login.url') || $self->config->get('global.loginurl') // '' },
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

    my $realm_map = $self->config->get_hash('realm.map');
    # legacy config
    $realm_map //= $self->config->get_hash('realm');
    for my $url_alias (keys $realm_map->%*) {
        my ($realm, $stack) = split (/\s*;\s*/, $realm_map->{$url_alias});
        $map->{$realm} //= [];
        push $map->{$realm}->@*, {
            url => $self->url_path_for($url_alias) . '/',
            stack => $stack,
        }
    };
    $self->log->trace('URL path and auth stacks by realm: ' . Dumper($map)) if $self->log->is_trace;
    return $map;
}

#
# METHODS
#

signature_for handle_login => (
    method => 1,
    positional => [
        'Str', 'Str', 'HashRef',
    ],
);
sub handle_login ($self, $page, $action, $reply) {
    my $uilogin = OpenXPKI::Client::Service::WebUI::Page::Login->new(webui => $self);

    $self->log->info("Not logged in - authenticating; page = '$page', action = '$action'");

    # Read login parameters "pki_realm" and "auth_stack"
    if ($action eq 'login!realm' and my $realm = scalar $self->param('pki_realm')) {
        $self->log->debug("Overwrite realm with '$realm' set via action '$action'");
        $self->session->param('pki_realm', $realm);
        $self->session->param('auth_stack', undef);
    }
    if ($action eq 'login!stack' and my $stack = scalar $self->param('auth_stack')) {
        $self->log->debug("Overwrite auth stack with '$stack' set via action '$action'");
        $self->session->param('auth_stack', $stack);
    }

    my $pki_realm = $self->session->param('pki_realm') || '';
    my $auth_stack =  $self->session->param('auth_stack') || '';

    # if this is an initial request, force redirect to the login page
    # will do an external redirect in case loginurl is set in config
    if ($action !~ /^login/ and $page !~ /^login/) {
        # Requests to pages can be redirected after login, store page in session
        if ($page and $page ne 'logout' and $page ne 'welcome') {
            $self->log->debug("Store page request in session for later redirect: $page");
            $self->session->param('redirect', $page);
        }

        # Link to an internal method using the class!method
        if (my $loginpage = $self->login_page) {

            # FIXME  this is not working
            $self->log->debug("Redirect to internal login page: $loginpage");
            return $self->handle_view($loginpage);

        } elsif (my $loginurl = $self->login_url) {

            $self->log->debug("Redirect to external login page: $loginurl");
            $uilogin->redirect->external($loginurl);

        } elsif ( $self->request->headers->header('X-OPENXPKI-Client') ) {

            # Session is gone but we are still in the Ember application
            $self->log->debug("Ember UI request with invalid backend session - redirect to login page");
            $uilogin->redirect->to('login');

        } else {

            # This is not an Ember request so we need to redirect back to the Ember page
            my $url = $self->base_url . '/#/openxpki/login';
            $self->log->debug('Redirect to login page: ' . $url);
            $uilogin->redirect->to($url);
        }
        return $uilogin;
    }

    # Login usually works in three steps realm -> auth stack -> credentials.
    # If there is only one realm, the server skips the realm selection phase.

    $self->log->debug(sprintf("Status: '%s'", $reply->{SERVICE_MSG}));

    # Only one realm? Redirect in "path" mode
    # (server skipped realm selection so we assume there is only one realm)
    if (
        'path' eq $self->realm_mode
        and $self->is_realm_selection_page
        and $reply->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK'
    ) {
        # fetch realm name
        $reply = $self->client->send_receive_service_msg('GET_REALM_LIST');
        my $realm_list = $reply->{PARAMS};

        my $error;
        if (scalar $realm_list->@* == 1) {
            my $realm = $realm_list->[0]->{name};
            if (my $paths = $self->realm_path_map->{$realm}) {
                if (scalar $paths->@* == 1) {
                    my $url = $paths->[0]->{url};
                    $self->log->debug("Only one realm - redirect to: $url");
                    $uilogin->redirect->external($url);
                    return $uilogin;
                } else {
                    $error = "Non-decidable redirect: config service.webui.realm.map contains more than one URL path for realm '$realm'";
                }
            } else {
                $error = "Missing redirect target: config service.webui.realm.map does not contain realm '$realm'";
            }
        } else {
            $error = "Non-decidable redirect: server skipped realm selection but there is more than one realm";
        }

        $self->log->error($error);
        $uilogin->status->error($error);
        return $uilogin;
    }

    # store realm in backend session if it's set
    if ( $reply->{SERVICE_MSG} eq 'GET_PKI_REALM' and $pki_realm) {
        $self->log->debug("Set chosen pki_realm '$pki_realm' in backend session");
        $reply = $self->client->send_receive_service_msg( 'GET_PKI_REALM', { PKI_REALM => $pki_realm } );
    }

    # if no realm set
    if ( $reply->{SERVICE_MSG} eq 'GET_PKI_REALM' and not $pki_realm) {
        $self->log->debug("No realm chosen, showing realm selection page");

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

    if ( $reply->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK' ) {
        # Never auth with an internal stack!
        if ( $auth_stack && $auth_stack !~ /^_/) {
            $self->log->debug("Authentication stack: $auth_stack");
            $reply = $self->client->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', {
               AUTHENTICATION_STACK => $auth_stack
            });
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
                $reply = $self->client->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', {
                    AUTHENTICATION_STACK => $auth_stack
                } );
            } else {
                $self->log->trace("Offering stacks: " . Dumper \@stack_list ) if $self->log->is_trace;
                $uilogin->init_auth_stack(\@stack_list);
                return $uilogin;
            }
        }
    }

    $self->log->debug(sprintf("Selected realm: '%s', new status: '%s'", $pki_realm, $reply->{SERVICE_MSG}));
    $self->log->trace('Reply = ' . Dumper $reply) if $self->log->is_trace;

    # we have more than one login handler and leave it to the login
    # class to render it right.
    if ( $reply->{SERVICE_MSG} =~ /GET_(.*)_LOGIN/ ) {
        my $login_type = $1;

        ## FIXME - need a good way to configure login handlers
        $self->log->info('Requested login type ' . $login_type );
        my $auth = $reply->{PARAMS};
        my $jws = $reply->{SIGN};

        # SSO Login uses data from the ENV, so no need to render anything
        if ( $login_type eq 'CLIENT' ) {
            $self->log->trace('Available webserver ENV: ' . join(', ', sort keys $self->request->env->%*)) if $self->log->is_trace;
            my $data;
            if ($auth->{envkeys}) {
                foreach my $key (keys %{$auth->{envkeys}}) {
                    my $envkey = $auth->{envkeys}->{$key};
                    $self->log->debug("Try to load '$key' from webserver ENV '$envkey'");
                    next unless defined $self->request->env->{$envkey};
                    $data->{$key} = Encode::decode('UTF-8', $self->request->env->{$envkey}, Encode::LEAVE_SRC | Encode::FB_CROAK);
                }
            # legacy support
            } elsif (my $user = $self->request->env->{OPENXPKI_USER} || $self->request->env->{REMOTE_USER}) {
                $data->{username} = $user;
                $data->{role} = $self->request->env->{OPENXPKI_GROUP} if $self->request->env->{OPENXPKI_GROUP};
            }

            # at least some items were found so we send them to the backend
            if ($data) {
                $self->log->trace('Sending auth data ' . Dumper $data) if $self->log->is_trace;

                $data = $self->_jwt_signature($data, $jws) if ($jws);

                $reply = $self->client->send_receive_service_msg( 'GET_CLIENT_LOGIN', $data );

            # as nothing was found we do not even try to login in and look for a redirect
            } elsif (my $loginurl = $auth->{login}) {

                # the login url might contain a backlink to the running instance
                $loginurl = OpenXPKI::Template->new->render( $loginurl,
                    { baseurl => $self->base_url } );

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
            my $user = $self->request->env->{SSL_CLIENT_S_DN_CN} || $self->request->env->{SSL_CLIENT_S_DN};
            my $cert = $self->request->env->{SSL_CLIENT_CERT} || '';

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

                $reply =  $self->client->send_receive_service_msg( 'GET_X509_LOGIN', $data);
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
                $reply = $self->client->send_receive_service_msg( 'GET_OIDC_LOGIN', {
                    token => $token,
                    client_id => $oidc_client{client_id},
                    nonce => $nonce,
                });

            } else {

                my $tt = OpenXPKI::Template->new;
                my $uri_pattern = $auth->{redirect_uri} || 'https://[% host _ baseurl %]';
                my $redirect_uri = $tt->render( $uri_pattern, {
                    host => $self->normalized_request_url->host,
                    baseurl => $self->base_url,
                    realm => $pki_realm,
                    stack => $auth_stack,
                });

                if (my $code = $self->param('code')) {

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
                    my $val = $self->param($field);
                    next unless ($val);
                    $data->{$field} = $val;
                }

                $data = $self->_jwt_signature($data, $jws) if ($jws);

                $reply = $self->client->send_receive_service_msg( 'GET_PASSWD_LOGIN', $data );
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
        $reply = $self->client->send_receive_service_msg( 'COMMAND',
            { COMMAND => 'get_session_info', PARAMS => {}, API => 2 } );

        if ( $reply->{SERVICE_MSG} eq 'COMMAND' ) {

            my $session_info = $reply->{PARAMS};

            # merge base URL to authinfo links
            # (we need to get the baseurl before recreating the session below)
            my $auth_info = {};
            if (my $ai = $session_info->{authinfo}) {
                my $tt = OpenXPKI::Template->new;
                for my $key (keys $ai->%*) {
                    $auth_info->{$key} = $tt->render(
                        $ai->{$key}, { baseurl => $self->base_url }
                    );
                }
            }
            delete $session_info->{authinfo};

            #$self->client->rekey_session;
            #my $new_backend_session_id = $self->client->get_session_id;

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
        $self->log->trace('Server error: '. Dumper $reply) if $self->log->is_trace;

        # Failure here is likely a wrong password
        my $msg = $reply->{'ERROR'} && $reply->{'ERROR'}->{CLASS} eq 'OpenXPKI::Exception::Authentication'
            ? $reply->{'ERROR'}->{LABEL}
            : $uilogin->message_from_error_reply($reply);

        $uilogin->status->error($msg);
        return $uilogin;
    }

    $self->log->error("Unhandled error during auth");
    $uilogin->status->error("Unhandled error during authentication");
    return $uilogin;

}

sub handle_logout ($self, $page) {
    return unless ($page eq 'logout' or $page eq 'login!logout');

    my $uilogin = OpenXPKI::Client::Service::WebUI::Page::Login->new(webui => $self);

    if ($page eq 'logout') {
        # For SSO Logins the session might hold an external link
        # to logout from the SSO provider
        my $authinfo = $self->session->param('authinfo') || {};
        my $goto = $authinfo->{logout};

        # create new frontend and backend sessions
        $self->logout_session; # pki_realm will be preserved

        # make sure backend session knows realm and frontend session knows
        # backend session so e.g. "get_menu" returns the proper logout menu from
        # the realm config (if any).
        $self->_init_client($self->client); # initialize backend session and store its ID in frontend session

        if (my $pki_realm = $self->session->param('pki_realm')) {
            # store realm in backend session
            my $reply = $self->ping_client;
            if ($reply->{SERVICE_MSG} eq 'GET_PKI_REALM') {
                $self->client->send_receive_service_msg('GET_PKI_REALM', {
                    PKI_REALM => $pki_realm,
                });
            }
        }

        # perform the redirect if set
        if ($goto) {
            $self->log->debug("External redirect on logout to: $goto");
            $uilogin->redirect->external($goto);
        } else {
            $uilogin->redirect->to('login!logout');
        }

        return $uilogin;
    }

    # show the "you have been logged out" page
    if ($page eq 'login!logout') {
        $uilogin->init_logout;
        return $uilogin;
    }

    return;
}

sub _jwt_signature ($self, $data, $jws) {
    return unless $self->has_auth;

    $self->log->debug('Sign data using key id ' . $jws->{keyid} );
    my $pkey = $self->auth;

    return encode_jwt(
        payload => {
            param => $data,
            sid => $self->client->get_session_id,
        },
        key => $pkey,
        auto_iat => 1,
        alg => 'ES256',
    );
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
    $self->new_frontend_session;

    map { $self->session->param($_, $keep{$_}) } keys %keep;

    # set some data
    $self->session->param('backend_session_id', $self->client->get_session_id );

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
    my $motd = $self->client->send_receive_command_msg( 'get_motd' );
    if (ref $motd->{PARAMS} eq 'HASH') {
        $self->log->trace('Got MOTD: '. Dumper $motd->{PARAMS} ) if $self->log->is_trace;
        $self->session->param('motd', $motd->{PARAMS} );
    }

    # Set menu
    $self->_set_menu;

    $self->session->flush;

}

sub _set_menu ($self) {
    my $reply = $self->client->send_receive_command_msg('get_menu');
    my $menu = $reply->{PARAMS} or return;

    $self->log->trace('UI config = ' . Dumper $menu) if $self->log->is_trace;

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
    # TODO Replace by proper config linter
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

1;
