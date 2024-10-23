package OpenXPKI::Client::Service::WebUI::Role::LoginHandler;
use OpenXPKI -role;
use namespace::autoclean;

requires 'log';
requires 'config';
requires 'session';
requires 'request';
requires 'backend';
requires 'realm_mode';
requires 'url_path';
requires 'auth';
requires 'has_auth';

requires 'param';
requires 'handle_view';
requires 'logout_session';
requires 'new_frontend_session';

# Core modules
use Encode;

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
    default => sub ($self) { $self->config->{global}->{loginpage} // '' },
);

has login_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->config->{global}->{loginurl} // '' },
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
    my $uilogin = OpenXPKI::Client::Service::WebUI::Page::Login->new(client => $self);

    # Login works in three steps realm -> auth stack -> credentials

    my $session = $self->session;

    # incoming logout command
    if ($page eq 'logout') {
        $uilogin->redirect->to('login!logout');
        return $uilogin;
    }

    # redirect to the "you have been logged out page"
    if ($page eq 'login!logout') {
        $uilogin->init_logout;
        return $uilogin;
    }

    $self->log->info("Not logged in. Doing auth. page = '$page', action = '$action'");

    # Special handling for "pki_realm" and "auth_stack" params
    if ($action eq 'login!realm' and $self->param('pki_realm')) {
        $self->session->param('pki_realm', scalar $self->param('pki_realm'));
        $self->session->param('auth_stack', undef);
        $self->log->debug('set realm in session: ' . $self->param('pki_realm') );
    }
    if ($action eq 'login!stack' and $self->param('auth_stack')) {
        $self->session->param('auth_stack', scalar $self->param('auth_stack'));
        $self->log->debug('set auth_stack in session: ' . $self->param('auth_stack') );
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
    if ($action !~ /^login/ and $page !~ /^login/) {
        # Requests to pages can be redirected after login, store page in session
        if ($page and $page ne 'logout' and $page ne 'welcome') {
            $self->log->debug("Store page request in session for later redirect: $page");
            $self->session->param('redirect', $page);
        }

        # Link to an internal method using the class!method
        if (my $loginpage = $self->login_page) {

            return $self->handle_view($loginpage);

        } elsif (my $loginurl = $self->login_url) {

            $self->log->debug("Redirect to external login page: $loginurl");
            $uilogin->redirect->external($loginurl);
            return $uilogin;

        } elsif ( $self->request->headers->header('X-OPENXPKI-Client') ) {

            # Session is gone but we are still in the ember application
            $uilogin->redirect->to('login');

        } else {

            # This is not an ember request so we need to redirect
            # back to the ember page - check if the session has a baseurl
            my $url = $self->session->param('baseurl');
            # if not, get the path from the referer
            if (not $url and (($self->request->headers->referrer//'') =~ m{https?://[^/]+(/[\w/]*[\w])/?}i)) {
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
        $self->log->trace('Server error: '. Dumper $reply) if $self->log->is_trace;

        # Failure here is likely a wrong password
        my $msg = $reply->{'ERROR'} && $reply->{'ERROR'}->{CLASS} eq 'OpenXPKI::Exception::Authentication'
            ? $reply->{'ERROR'}->{LABEL}
            : $uilogin->message_from_error_reply($reply);

        $uilogin->status->error($msg);
        return $uilogin;
    }

    $self->log->debug("unhandled error during auth");
    return;

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

    # Set menu
    $self->_set_menu;

    $self->session->flush;

}

sub _set_menu ($self) {
    my $reply = $self->backend->send_receive_command_msg('get_menu');
    my $menu = $reply->{PARAMS} or return;

    $self->log->trace('Menu = ' . Dumper $menu) if $self->log->is_trace;

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

1;
