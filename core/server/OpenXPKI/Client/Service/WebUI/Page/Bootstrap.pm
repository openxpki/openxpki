package OpenXPKI::Client::Service::WebUI::Page::Bootstrap;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page';

# Core modules
use Digest::SHA;

# Project modules
use OpenXPKI::i18n qw( get_language );


sub init_structure ($self, $args) {
    my $user = $self->session_param('user') || undef;

    # create CSRF token
    if (!$self->session_param('rtoken')) {
        $self->log->debug('Generate rtoken');
        $self->session_param('rtoken', Digest::SHA::sha1_hex($$ . $self->session->id . rand(2**32)));
    }
    $self->rtoken($self->session_param('rtoken'));

    $self->language(get_language());

    # add PKI realm if CGI session contains one
    if (my $realm = $self->session_param('pki_realm')) {
        $self->pki_realm($realm);
    }

    # Store the referrer to be able to issue internal UI redirects (without
    # specifying the full path).
    #
    # We use a Browser-sent URL here because the Ember web UI (index.html)
    # could have a different URL than the asynchronously called (CGI) backend.
    # E.g.
    #   Ember UI: https://localhost:9443/webui/democa/
    #   Backend:  https://localhost:9443/cgi-bin/webui.fcgi
    my $baseurl = $self->param('baseurl') || '/openxpki'; # default /openxpki is mainly relevant for test scripts

    # strip spaces and trailing slash
    $baseurl =~ s{(\A\s+|\s+\z|/\z)}{}g;
    # prevent injection of external urls
    $baseurl =~ s{\w+://[^/]+}{};

    $self->session_param('baseurl',  $baseurl );
    $self->session->flush;
    $self->log->debug("Base URL from referrer: " . $baseurl);

    if ($self->session_param('is_logged_in') and $user) {
        $self->set_user(%{ $user });

        # Preselect tenant, for now we just pick the first from the list
        if ($user->{tenants}) {
            $self->tenant($user->{tenants}->[0]->{value});
            $self->log->trace('Preset tenant from items ' . Dumper $user->{tenants}) if $self->log->is_trace;
        }

        # Last Login
        if (my $last_login = $self->session_param('userinfo')->{last_login}) {
            $self->user->last_login($last_login);
        }

        # Ping endpoint
        if (my $ping = $self->session_param('ping')) {
            $self->ping($ping);
        }

        # Redirection targets for apache based SSO Handling
        if (my $auth = $self->session_param('authinfo')) {
            if (my $target = ($auth->{resume} || $auth->{login})) {
                $self->on_exception->add_handler(
                    status_code => [ 403, 401 ],
                    redirect => $target,
                );
            }
        }
    }

    # Configured menu items
    if (my $menu = $self->session_param('menu_items')) { # session parameter is set in OpenXPKI::Client::Service::WebUI::Role::LoginHandler->_set_menu()
        $self->menu->items($menu);

    # Default (Logout) menu
    } else {
        $self->menu->items([
            {
                key => 'login',
                label => 'I18N_OPENXPKI_UI_MENU_LOGIN',
                icon => 'glyphicon-log-in',
            },
            {
                key => 'logout',
                label => 'I18N_OPENXPKI_UI_CLEAR_LOGIN',
                icon => 'glyphicon-eject',
            },
            # I18N_OPENXPKI_UI_MENU_REALM_SELECTION
        ]) unless $self->menu->is_set;
    }

    return $self;
}


sub page_not_found ($self) {
    $self->main->add_section({
        type => 'text',
        content => {
            headline => 'I18N_OPENXPKI_UI_OOPS',
            paragraphs => [{text=>'I18N_OPENXPKI_UI_OOPS'}]
        }
    });

    $self->status->error('I18N_OPENXPKI_UI_PAGE_NOT_FOUND');

    return $self;
}

__PACKAGE__->meta->make_immutable;
