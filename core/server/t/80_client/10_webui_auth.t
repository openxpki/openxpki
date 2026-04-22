#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";

# Core modules
use Data::Dumper;

# CPAN modules
use Test2::V0;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ level => $ENV{TEST_VERBOSE} ? $DEBUG : $OFF, layout => '# %m%n' });

use OpenXPKI::Client::Service::WebUI::Auth;

# ---------------------------------------------------------------------------
# MockSession - in-memory key/value store replacing WebUI::Session
# ---------------------------------------------------------------------------

{
    package MockSession;
    sub new  { bless { _data => {} }, shift }
    sub param {
        my ($self, $key, $val) = @_;
        $self->{_data}{$key} = $val if @_ > 2;
        return $self->{_data}{$key};
    }
}

# ---------------------------------------------------------------------------
# MockClient - dispatch-based stub replacing OpenXPKI::Client
#
# Constructed with a 'replies' hashref: keys are command names passed as
# the first argument to send_receive_service_msg() or send_receive_command_msg().
# Each value is either a plain hashref (returned as-is) or a CODE ref called
# with ($cmd, @remaining_args) so that tests can inspect arguments or cycle
# through multiple replies for the same command.
# A '*' key acts as a catch-all for unregistered commands.
# ---------------------------------------------------------------------------

{
    package MockClient;
    sub new {
        my ($class, %args) = @_;
        bless { _replies => $args{replies} // {}, session_id => 'fake-sid' }, $class;
    }
    sub _reply_for {
        my ($self, $cmd, @args) = @_;
        my $r = $self->{_replies}{$cmd}
             // $self->{_replies}{'*'}
             // { SERVICE_MSG => 'ERROR', ERROR => {} };
        return ref $r eq 'CODE' ? $r->($cmd, @args) : $r;
    }
    sub send_receive_service_msg { my ($self, $cmd, @a) = @_; $self->_reply_for($cmd, @a) }
    sub send_receive_command_msg { my ($self, $cmd, @a) = @_; $self->_reply_for($cmd, @a) }
    sub get_session_id { 'fake-sid' }
}

# ---------------------------------------------------------------------------
# make_webui - assemble a minimal WebUI stub
#
# Named arguments:
#   config    - flat hashref: keys are dot-path strings, values are the reply
#   session   - MockSession instance (new one created if omitted)
#   client    - MockClient instance (new one created if omitted)
#   env       - hashref of fake webserver ENV vars (SSL_*, REMOTE_USER, etc.)
#   params    - hashref of fake request params (username, password, etc.)
#   realm_mode        - 'select' (default), 'path', or 'hostname'
#   realm_selection_layout - 'cards' (default) or 'list'
#   base_url          - default 'https://host/'
#   has_x_client_header - bool: simulate X-OPENXPKI-Client header present
# ---------------------------------------------------------------------------

sub make_webui {
    my (%args) = @_;

    my $session  = $args{session} // MockSession->new;
    my $client   = $args{client}  // MockClient->new;
    my $cfg      = $args{config}  // {};
    my $env      = $args{env}     // {};
    my $params   = $args{params}  // {};
    my $base_url = $args{base_url} // 'https://host/';

    # --- config stub ---
    my $config = mock {} => add => [
        get => sub {
            my ($self, $key) = @_;
            $key = join('.', @$key) if ref $key eq 'ARRAY';
            return $cfg->{$key};
        },
        get_hash => sub { $cfg->{$_[1]} },
    ];

    # --- request headers stub ---
    my $has_xc = $args{has_x_client_header} // 0;
    my $headers = mock {} => add => [
        header => sub {
            my ($self, $h) = @_;
            return $has_xc if $h eq 'X-OPENXPKI-Client';
            return undef;
        },
    ];

    # --- request stub ---
    my $request = mock { _env => $env, _headers => $headers } => add => [
        env     => sub { $_[0]->{_env} },
        headers => sub { $_[0]->{_headers} },
        cookie  => sub { undef },
    ];

    # --- real Response object (redirect, status, etc. are the real DTOs) ---
    require Mojo::Message::Request;
    require OpenXPKI::Client::Service::WebUI::SessionCookie;
    require OpenXPKI::Client::Service::WebUI::Response;
    my $session_cookie = OpenXPKI::Client::Service::WebUI::SessionCookie->new(
        request => Mojo::Message::Request->new,
    );
    my $ui_response = OpenXPKI::Client::Service::WebUI::Response->new(
        session_cookie => $session_cookie,
    );

    # --- URI stub (returned by normalized_request_url) ---
    my $uri = mock {} => add => [ host => sub { 'host' } ];

    # --- request params stub ---
    my $request_params = mock {} => add => [
        param => sub { $params->{$_[1]} },
    ];

    # --- webui stub ---
    # Blessed into the real class so the Moose 'isa' check on Auth->webui passes.
    # mock() patches the class stash and returns a controller; the controller must
    # remain alive for the duration of the test (stored in the webui hashref).
    my $webui_pkg = 'OpenXPKI::Client::Service::WebUI';
    my $webui = bless {
        _session             => $session,
        _client              => $client,
        _config              => $config,
        _request             => $request,
        _ui_response         => $ui_response,
        _base_url            => $base_url,
        _realm_mode          => $args{realm_mode}   // 'select',
        _realm_selection_layout   => $args{realm_selection_layout} // 'card',
        _logout_called       => 0,
        _init_client_called  => 0,
        _ping_replies        => $args{ping_replies} // [],
    }, $webui_pkg;

    $webui->{_mock_ctrl} = mock $webui_pkg => set => [
        config       => sub { $_[0]->{_config} },
        session      => sub { $_[0]->{_session} },
        client       => sub { $_[0]->{_client} },
        request      => sub { $_[0]->{_request} },
        ui_response  => sub { $_[0]->{_ui_response} },
        base_url     => sub { $_[0]->{_base_url} },
        script_url   => sub { $_[0]->{_base_url} },
        realm_mode   => sub { $_[0]->{_realm_mode} },
        realm_selection_layout => sub { $_[0]->{_realm_selection_layout} },
        param        => sub { $params->{$_[1]} },
        url_path_for => sub { '/' . $_[1] },
        is_realm_selection_page => sub { 0 },
        realm_selection_conf    => sub { { layout => $_[0]->{_realm_selection_layout} } },
        logout_session          => sub { $_[0]->{_logout_called}++ },
        new_frontend_session    => sub {
            $_[0]->{_session} = MockSession->new;
            $_[0]->{_ui_response} = OpenXPKI::Client::Service::WebUI::Response->new(
                session_cookie => OpenXPKI::Client::Service::WebUI::SessionCookie->new(
                    request => Mojo::Message::Request->new,
                ),
            );
        },
        has_cipher              => sub { 0 },
        _init_client            => sub { $_[0]->{_init_client_called}++ },
        ping_client             => sub {
            my $r = shift @{ $_[0]->{_ping_replies} // [] };
            $r // { SERVICE_MSG => 'OK' };
        },
        dispatcher              => sub { die "dispatcher not expected in this test" },
        normalized_request_url  => sub { $uri },
        request_params          => sub { $request_params },
    ];

    return $webui;
}

# Returns ($auth, $webui). The caller must hold $webui in a lexical for the
# duration of the test — Auth stores it as a weak_ref and it will be garbage
# collected if no strong reference is kept.  The mock controller is kept alive
# inside $webui->{_mock_ctrl} for the same reason.
sub new_auth {
    my (%args) = @_;
    my $webui = make_webui(%args);
    my $auth = OpenXPKI::Client::Service::WebUI::Auth->new(
        webui => $webui,
        log   => Log::Log4perl->get_logger,
    );
    return ($auth, $webui);
}

# ---------------------------------------------------------------------------
# is_logout()
# ---------------------------------------------------------------------------

subtest 'is_logout() identifies logout strings' => sub {
    my ($auth, $webui) = new_auth();
    ok  $auth->is_logout('logout'),       '"logout" is a logout page';
    ok  $auth->is_logout('login!logout'), '"login!logout" is a logout page';
    ok !$auth->is_logout('home'),         '"home" is not a logout page';
    ok !$auth->is_logout('login'),        '"login" is not a logout page';
    ok !$auth->is_logout(''),             'empty string is not a logout page';
};

# ---------------------------------------------------------------------------
# logout()
# ---------------------------------------------------------------------------

subtest 'logout() - non-logout page dies' => sub {
    my ($auth, $webui) = new_auth();
    ok dies { $auth->logout('home')  }, 'page=home dies';
    ok dies { $auth->logout('')      }, 'empty page dies';
    ok dies { $auth->logout('login') }, 'page=login dies';
};

subtest 'logout() - login!logout renders the logged-out confirmation page' => sub {
    my ($auth, $webui) = new_auth();
    my $page = $auth->logout('login!logout');
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->page->label, 'I18N_OPENXPKI_UI_HOME_LOGOUT_HEAD', 'shows logged-out confirmation string';
};

subtest 'logout() - logout without SSO redirect clears session and redirects to login!logout' => sub {
    my $session = MockSession->new;
    $session->param('authinfo', {});   # no 'logout' key

    my ($auth, $webui) = new_auth(session => $session);
    my $page = $auth->logout('logout');

    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    ok $auth->webui->{_logout_called}, 'logout_session was called';
    ok $auth->webui->{_init_client_called}, '_init_client was called';
    is $page->redirect->to, 'login!logout', 'redirects to login!logout';
    is $page->redirect->type, 'internal', 'redirect type is internal';
};

subtest 'logout() - logout with SSO redirect performs external redirect' => sub {
    my $session = MockSession->new;
    $session->param('authinfo', { logout => 'https://sso.example.com/logout' });

    my ($auth, $webui) = new_auth(session => $session);
    my $page = $auth->logout('logout');

    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->redirect->to,   'https://sso.example.com/logout', 'redirects to SSO logout URL';
    is $page->redirect->type, 'external', 'redirect type is external';
};

subtest 'logout() - logout with fixed realm re-initialises backend realm' => sub {
    my $session = MockSession->new;
    $session->param('authinfo', {});
    $session->param('pki_realm', 'democa');
    $session->param('is_fixed_auth_stack', 1);
    $session->param('auth_stack', 'Local');

    my @captured;
    my $client = MockClient->new(replies => {
        # capture the GET_PKI_REALM call so we can assert its arguments
        'GET_PKI_REALM' => sub {
            my ($cmd, $params) = @_;
            push @captured, $params;
            return { SERVICE_MSG => 'OK' };
        },
    });

    my ($auth, $webui) = new_auth(
        session      => $session,
        client       => $client,
        ping_replies => [{ SERVICE_MSG => 'GET_PKI_REALM' }],
    );
    my $page = $auth->logout('logout');

    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is \@captured, [ { PKI_REALM => 'democa', AUTHENTICATION_STACK => 'Local' } ],
        'GET_PKI_REALM sent to backend with realm and fixed auth stack';
};

# ---------------------------------------------------------------------------
# login() - initial redirect (non-login page/action)
# ---------------------------------------------------------------------------

subtest 'login() - non-login page, no loginurl, no Ember header -> base URL redirect' => sub {
    my ($auth, $webui) = new_auth(config => {});
    my $page = $auth->login('home', '', { SERVICE_MSG => 'GET_PKI_REALM', PARAMS => {} });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->redirect->to, 'https://host//#/openxpki/login', 'redirect is set';
};

subtest 'login() - non-login page with loginurl -> external redirect' => sub {
    my ($auth, $webui) = new_auth(config => { 'login.url' => 'https://external-login.example.com/' });
    my $page = $auth->login('some_page', '', { SERVICE_MSG => 'GET_PKI_REALM', PARAMS => {} });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->redirect->type, 'external', 'redirect type is external';
    is $page->redirect->to, 'https://external-login.example.com/', 'redirect target is loginurl';
};

subtest 'login() - non-login page with X-OPENXPKI-Client header -> internal redirect to login' => sub {
    my ($auth, $webui) = new_auth(has_x_client_header => 1);
    my $page = $auth->login('', '', { SERVICE_MSG => 'GET_PKI_REALM', PARAMS => {} });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->redirect->to, 'login', 'redirect target is "login"';
};

subtest 'login() - non-login page stores page in session for later redirect' => sub {
    my $session = MockSession->new;
    my ($auth, $webui) = new_auth(session => $session);
    $auth->login('workflow!search', '', { SERVICE_MSG => 'GET_PKI_REALM', PARAMS => {} });
    is $session->param('redirect'), 'workflow!search', 'page stored in session for redirect';
};

subtest 'login() - page=logout not stored as redirect target' => sub {
    my $session = MockSession->new;
    my ($auth, $webui) = new_auth(session => $session);
    $auth->login('logout', '', { SERVICE_MSG => 'GET_PKI_REALM', PARAMS => {} });
    is $session->param('redirect'), undef, 'logout page not stored as redirect';
};

# ---------------------------------------------------------------------------
# login() - realm selection
# ---------------------------------------------------------------------------

subtest 'login() - GET_PKI_REALM without session realm -> show realm cards' => sub {
    my ($auth, $webui) = new_auth();
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_PKI_REALM',
        PARAMS => {
            PKI_REALMS => {
                democa => { LABEL => 'Demo CA', DESCRIPTION => '', NAME => 'democa', AUTH_STACKS => {} },
            },
        },
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->ui_response->resolve->{page}->{description}, 'I18N_OPENXPKI_UI_LOGIN_REALM_SELECTION_DESC', 'shows realm selection';
};

subtest 'login() - action login!realm stores chosen realm in session' => sub {
    my $session = MockSession->new;
    my $client = MockClient->new(replies => {
        'GET_PKI_REALM' => {
            SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
            PARAMS => {
                AUTHENTICATION_STACKS => {
                    Local => { name => 'Local', label => 'Local Users', description => '' },
                    Cert  => { name => 'Cert',  label => 'Certificate', description => '' },
                },
            },
        },
    });
    my ($auth, $webui) = new_auth(
        session => $session,
        client  => $client,
        params  => { pki_realm => 'democa' },
    );
    $auth->login('login', 'login!realm', { SERVICE_MSG => 'GET_PKI_REALM', PARAMS => {} });
    is $session->param('pki_realm'), 'democa', 'realm written to session';
    is $session->param('auth_stack'), undef,   'auth_stack cleared when realm changes';
};

# ---------------------------------------------------------------------------
# login() - auth-stack selection
# ---------------------------------------------------------------------------

subtest 'login() - GET_AUTHENTICATION_STACK with multiple stacks -> show stack selector' => sub {
    my ($auth, $webui) = new_auth();
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
        PARAMS => {
            AUTHENTICATION_STACKS => {
                Local => { name => 'Local', label => 'Local Users', description => '' },
                Cert  => { name => 'Cert',  label => 'Certificate', description => '' },
            },
        },
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->ui_response->resolve->{page}->{description}, 'I18N_OPENXPKI_UI_LOGIN_STACK_SELECTION_DESC', 'shows auth stack selection';
};

subtest 'login() - GET_AUTHENTICATION_STACK with single public stack -> autoselect' => sub {
    my $session = MockSession->new;
    my $client = MockClient->new(replies => {
        'GET_AUTHENTICATION_STACK' => {
            SERVICE_MSG => 'GET_PASSWD_LOGIN',
            PARAMS => { field => [] },
            SIGN   => undef,
        },
    });
    my ($auth, $webui) = new_auth(session => $session, client => $client);
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
        PARAMS => {
            AUTHENTICATION_STACKS => {
                Local => { name => 'Local', label => 'Local Users', description => '' },
            },
        },
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $session->param('auth_stack'), 'Local', 'autoselected stack stored in session';
};

subtest 'login() - GET_AUTHENTICATION_STACK skips internal stacks (name starts with _)' => sub {
    my ($auth, $webui) = new_auth();
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
        PARAMS => {
            AUTHENTICATION_STACKS => {
                alice => { name => 'Alice', label => '', description => '' },
                bob => { name => 'Bob', label => '', description => '' },
                _hidden => { name => '_Hidden', label => '', description => '' },
            },
        },
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    my $contents = Dumper $page->ui_response->resolve;
    like $contents, qr/Alice/, 'shows public stack';
    unlike $contents, qr/Hidden/, 'hides internal stack';
};

subtest 'login() - action login!stack stores chosen stack in session' => sub {
    my $session = MockSession->new;
    my $client = MockClient->new(replies => {
        'GET_AUTHENTICATION_STACK' => {
            SERVICE_MSG => 'GET_PASSWD_LOGIN',
            PARAMS => { field => [] },
            SIGN   => undef,
        },
    });
    my ($auth, $webui) = new_auth(
        session => $session,
        client  => $client,
        params  => { auth_stack => 'Local' },
    );
    $auth->login('login', 'login!stack', {
        SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
        PARAMS => {
            AUTHENTICATION_STACKS => {
                Local => { name => 'Local', label => 'Local', description => '' },
                Cert  => { name => 'Cert',  label => 'Cert',  description => '' },
            },
        },
    });
    is $session->param('auth_stack'), 'Local', 'chosen stack written to session';
};

subtest 'login() - login!stack with internal stack name: internal stack filtered, remaining public stack autoselected' => sub {
    my $session = MockSession->new;
    my $client = MockClient->new(replies => {
        # autoselect sends GET_AUTHENTICATION_STACK to backend
        'GET_AUTHENTICATION_STACK' => {
            SERVICE_MSG => 'GET_PASSWD_LOGIN',
            PARAMS => { field => [] },
            SIGN   => undef,
        },
    });
    my ($auth, $webui) = new_auth(
        session => $session,
        client  => $client,
        params  => { auth_stack => '_hidden' },
    );
    $auth->login('login', 'login!stack', {
        SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
        PARAMS => {
            AUTHENTICATION_STACKS => {
                Local   => { name => 'Local',   label => 'Local',  description => '' },
                _hidden => { name => '_hidden', label => 'Hidden', description => '' },
            },
        },
    });
    # _hidden is written to session by the login!stack action handler, but the
    # _handle_GET_AUTHENTICATION_STACK guard ("!~ /^_/") does not submit it to the
    # backend.  With only one visible public stack (Local), autoselect fires and
    # overwrites the session with the correct value.
    is $session->param('auth_stack'), 'Local', 'autoselect overwrites the internal stack value';
};

# ---------------------------------------------------------------------------
# login() - password login
# ---------------------------------------------------------------------------

subtest 'login() - GET_PASSWD_LOGIN without login!password action -> render password form' => sub {
    my ($auth, $webui) = new_auth();
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_PASSWD_LOGIN',
        PARAMS      => { field => [] },
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    like $page->ui_response->resolve, hash {
        field main => array {
            item 0 => hash {
                field type   => 'form';
                field action => 'login!password';
                etc;
            };
            etc;
        };
        etc;
    };
};

subtest 'login() - GET_PASSWD_LOGIN with login!password and wrong credentials -> error page' => sub {
    my $client = MockClient->new(replies => {
        'GET_PASSWD_LOGIN' => { SERVICE_MSG => 'ERROR', ERROR => {
            CLASS => 'OpenXPKI::Exception::Authentication',
            LABEL => 'Wrong credentials',
        }},
    });
    my ($auth, $webui) = new_auth(
        client => $client,
        params => { username => 'alice', password => 'wrong' },
    );
    my $page = $auth->login('login', 'login!password', {
        SERVICE_MSG => 'GET_PASSWD_LOGIN',
        PARAMS      => { field => [] },
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->status->level, 'error', 'status level is error';
    like $page->status->message, qr/Wrong credentials/, 'error message propagated';
};

subtest 'login() - GET_PASSWD_LOGIN successful auth -> redirects to welcome' => sub {
    my $client = MockClient->new(replies => {
        'GET_PASSWD_LOGIN' => { SERVICE_MSG => 'SERVICE_READY' },
        'COMMAND' => { SERVICE_MSG => 'COMMAND', PARAMS => {
            pki_realm => 'democa',
            userinfo  => { cn => 'Alice' },
            authinfo  => {},
        }},
        'get_motd' => { SERVICE_MSG => 'COMMAND', PARAMS => undef },
        'get_menu'  => { SERVICE_MSG => 'COMMAND', PARAMS => { main => [] } },
    });
    my ($auth, $webui) = new_auth(
        client => $client,
        params => { username => 'alice', password => 'correct' },
    );
    my $page = $auth->login('login', 'login!password', {
        SERVICE_MSG => 'GET_PASSWD_LOGIN',
        PARAMS      => { field => [] },
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $auth->webui->session->param('is_logged_in'), 1,       'session marked as logged in';
    is $auth->webui->session->param('pki_realm'),    'democa', 'realm stored in session';
};

subtest 'login() - GET_PASSWD_LOGIN successful auth with authinfo login redirect' => sub {
    my $client = MockClient->new(replies => {
        'GET_PASSWD_LOGIN' => { SERVICE_MSG => 'SERVICE_READY' },
        'COMMAND' => { SERVICE_MSG => 'COMMAND', PARAMS => {
            pki_realm => 'democa',
            userinfo  => {},
            authinfo  => { login => 'mypage!landing' },
        }},
        'get_motd' => { SERVICE_MSG => 'COMMAND', PARAMS => undef },
        'get_menu'  => { SERVICE_MSG => 'COMMAND', PARAMS => { main => [] } },
    });
    my ($auth, $webui) = new_auth(
        client => $client,
        params => { username => 'alice', password => 'correct' },
    );
    my $page = $auth->login('login', 'login!password', {
        SERVICE_MSG => 'GET_PASSWD_LOGIN',
        PARAMS      => { field => [] },
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->redirect->to, 'mypage!landing', 'redirects to authinfo login page';
};

# ---------------------------------------------------------------------------
# login() - X.509 certificate login
# ---------------------------------------------------------------------------

subtest 'login() - GET_X509_LOGIN with client cert -> sends to backend' => sub {
    my $client = MockClient->new(replies => {
        'GET_X509_LOGIN' => { SERVICE_MSG => 'ERROR', ERROR => {
            CLASS => 'OpenXPKI::Exception::Authentication',
            LABEL => 'Cert not trusted',
        }},
    });
    my ($auth, $webui) = new_auth(
        client => $client,
        env    => {
            SSL_CLIENT_CERT    => '-----BEGIN CERTIFICATE-----...',
            SSL_CLIENT_S_DN_CN => 'alice',
        },
    );
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_X509_LOGIN',
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->status->level, 'error', 'authentication error reported';
};

subtest 'login() - GET_X509_LOGIN without client cert -> missing-data page' => sub {
    my ($auth, $webui) = new_auth(env => {});
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_X509_LOGIN',
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    ok $auth->webui->{_logout_called}, 'session cleared on missing cert';
};

# ---------------------------------------------------------------------------
# login() - SSO / CLIENT login
# ---------------------------------------------------------------------------

subtest 'login() - GET_CLIENT_LOGIN with REMOTE_USER in ENV -> sends username to backend' => sub {
    my @captured;
    my $client = MockClient->new(replies => {
        'GET_CLIENT_LOGIN' => sub {
            my ($cmd, $params) = @_;
            push @captured, $params;
            return { SERVICE_MSG => 'ERROR', ERROR => {} };
        },
    });
    my ($auth, $webui) = new_auth(
        client => $client,
        env    => { REMOTE_USER => 'alice' },
    );
    $auth->login('login', '', {
        SERVICE_MSG => 'GET_CLIENT_LOGIN',
        PARAMS      => {},
        SIGN        => undef,
    });
    is \@captured, [ { username => 'alice' } ],
        'GET_CLIENT_LOGIN sent with username extracted from REMOTE_USER';
};

subtest 'login() - GET_CLIENT_LOGIN with configured envkeys -> sends mapped ENV vars to backend' => sub {
    my @captured;
    my $client = MockClient->new(replies => {
        'GET_CLIENT_LOGIN' => sub {
            my ($cmd, $params) = @_;
            push @captured, $params;
            return { SERVICE_MSG => 'ERROR', ERROR => {} };
        },
    });
    my ($auth, $webui) = new_auth(
        client => $client,
        env    => { HTTP_X_USER => 'alice', HTTP_X_ROLE => 'User' },
    );
    $auth->login('login', '', {
        SERVICE_MSG => 'GET_CLIENT_LOGIN',
        PARAMS      => { envkeys => { username => 'HTTP_X_USER', role => 'HTTP_X_ROLE' } },
        SIGN        => undef,
    });
    is \@captured, [ { username => 'alice', role => 'User' } ],
        'GET_CLIENT_LOGIN sent with values mapped from configured envkeys';
};

subtest 'login() - GET_CLIENT_LOGIN without ENV data and with login redirect -> external redirect' => sub {
    my ($auth, $webui) = new_auth(env => {}, base_url => 'https://host/');
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_CLIENT_LOGIN',
        PARAMS      => { envkeys => {}, login => 'https://sso.example.com/[% baseurl %]' },
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->redirect->type, 'external', 'redirect type is external';
    like $page->redirect->to, qr{https://sso\.example\.com/}, 'redirect URL contains SSO base';
};

subtest 'login() - GET_CLIENT_LOGIN without ENV data and no login redirect -> missing-data page' => sub {
    my ($auth, $webui) = new_auth(env => {});
    my $page = $auth->login('login', '', {
        SERVICE_MSG => 'GET_CLIENT_LOGIN',
        PARAMS      => { envkeys => {} },
        SIGN        => undef,
    });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    ok $auth->webui->{_logout_called}, 'session cleared on missing SSO data';
};

# ---------------------------------------------------------------------------
# login() - unknown SERVICE_MSG
# ---------------------------------------------------------------------------

subtest 'login() - unknown SERVICE_MSG -> unhandled error page' => sub {
    my ($auth, $webui) = new_auth();
    my $page = $auth->login('login', '', { SERVICE_MSG => 'SOMETHING_UNEXPECTED' });
    isa_ok $page, 'OpenXPKI::Client::Service::WebUI::Page';
    is $page->status->level, 'error', 'status level is error';
};

done_testing;
