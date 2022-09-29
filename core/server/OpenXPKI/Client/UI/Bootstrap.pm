# OpenXPKI::Client::UI::Bootstrap
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bootstrap;
use Moose;

extends 'OpenXPKI::Client::UI::Result';

# Core modules
use Data::Dumper;
use Digest::SHA;

# Project modules
use OpenXPKI::i18n qw( i18nTokenizer get_language );


sub init_structure {

    my $self = shift;
    my $session = $self->_session;
    my $user = $session->param('user') || undef;

    # create CSRF token
    if (!$session->param('rtoken')) {
        $self->logger->debug('Generate rtoken');
        $session->param('rtoken', Digest::SHA::sha1_hex( $$. $session->id() . rand(2**32) ) );
    }
    $self->resp->result->{rtoken} = $session->param('rtoken');

    $self->resp->result->{language} = get_language();

    # To issue redirects to the UI, we store the referrer
    # default is mainly relevant for test scripts
    my $baseurl = $self->param('baseurl') || '/openxpki';
    $baseurl =~ s|/$||;
    $session->param('baseurl',  $baseurl.'/#/');
    $session->flush;
    $self->logger->debug("Baseurl from referrer: " . $baseurl);

    if ($session->param('is_logged_in') && $user) {
        $self->resp->result->{user} = $user;

        # Preselect tenant, for now we just pick the first from the list
        if ($user->{tenants}) {
            $self->resp->result->{tenant} = $user->{tenants}->[0]->{value};
            $self->logger->trace('Preset tenant from items ' . Dumper $user->{tenants}) if $self->logger->is_trace;
        }

        # Last Login
        if (my $last_login = $session->param('userinfo')->{last_login}) {
            $user->{last_login} = $last_login;
        }

        $self->resp->result->{structure} = $session->param('menu');

        # Ping endpoint
        if (my $ping = $session->param('ping')) {
            $self->resp->result->{ping} = $ping;
        }

        # Redirection targets for apache based SSO Handling
        if (my $auth = $session->param('authinfo')) {
            if (my $target = ($auth->{resume} || $auth->{login})) {
                $self->resp->result->{on_exception} = [{
                    status_code => [ 403, 401 ],
                    redirect => $target,
                }];
            }
        }
    }

    # default menu if nothing was set before
    $self->resp->result->{structure} ||= [{
        key => 'logout',
        label => 'I18N_OPENXPKI_UI_CLEAR_LOGIN',
        entries => [],
    }];

    return $self;

}


sub init_error {

    my $self = shift;
    my $args = shift;

    $self->add_section({
        type => 'text',
        content => {
            headline => 'I18N_OPENXPKI_UI_OOPS',
            paragraphs => [{text=>'I18N_OPENXPKI_UI_OOPS'}]
        }
    });

    return $self;
}
1;
