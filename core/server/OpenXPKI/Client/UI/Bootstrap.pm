package OpenXPKI::Client::UI::Bootstrap;
use Moose;

extends 'OpenXPKI::Client::UI::Result';

# Core modules
use Data::Dumper;
use Digest::SHA;

# Project modules
use OpenXPKI::i18n qw( get_language );


sub init_structure {

    my $self = shift;
    my $user = $self->session_param('user') || undef;

    # create CSRF token
    if (!$self->session_param('rtoken')) {
        $self->log->debug('Generate rtoken');
        $self->session_param('rtoken', Digest::SHA::sha1_hex($$ . $self->_session->id . rand(2**32)));
    }
    $self->rtoken($self->session_param('rtoken'));

    $self->language(get_language());

    # add PKI realm if CGI session contains one
    if (my $realm = $self->session_param('pki_realm')) {
        $self->pki_realm($realm);
    }

    # To issue redirects to the UI, we store the referrer
    # default is mainly relevant for test scripts
    my $baseurl = $self->param('baseurl') || '/openxpki';
    $baseurl =~ s{(\A\s+|\s+\z|/\z)}{}g;
    # prevent injection of external urls
    $baseurl =~ s{\w+://[^/]+}{};
    $self->session_param('baseurl',  $baseurl.'/#/');
    $self->_session->flush;
    $self->log->debug("Baseurl from referrer: " . $baseurl);

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

        # Menu items
        $self->menu->items($self->session_param('menu_items'));

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

    # default menu if nothing was set before
    $self->menu->add_item({
        key => 'logout',
        label => 'I18N_OPENXPKI_UI_CLEAR_LOGIN',
    }) unless $self->menu->is_set;

    return $self;

}


sub init_error {

    my $self = shift;
    my $args = shift;

    $self->main->add_section({
        type => 'text',
        content => {
            headline => 'I18N_OPENXPKI_UI_OOPS',
            paragraphs => [{text=>'I18N_OPENXPKI_UI_OOPS'}]
        }
    });

    return $self;
}

__PACKAGE__->meta->make_immutable;
