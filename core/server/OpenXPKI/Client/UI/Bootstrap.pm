# OpenXPKI::Client::UI::Bootstrap
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bootstrap;

use Moose;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use OpenXPKI::i18n qw( i18nTokenizer get_language );

extends 'OpenXPKI::Client::UI::Result';

sub init_structure {

    my $self = shift;
    my $session = $self->_session;
    my $user = $session->param('user') || undef;

    if (!$session->param('rtoken')) {
        $self->logger()->debug('Generate rtoken');
        $session->param('rtoken', sha1_hex( $$. $session->id() . rand(2**32) ) );
    }
    $self->_result()->{rtoken} = $session->param('rtoken');
    $self->_result()->{language} = get_language();

    # To issue redirects to the UI, we store the referrer
    # default is mainly relevant for test scripts
    my $baseurl = $self->param('baseurl') || '/openxpki';
    $baseurl =~ s|/$||;
    $session->param('baseurl',  $baseurl.'/#/');
    $self->logger->debug("Baseurl from referrer: " . $baseurl);

    if ($session->param('is_logged_in') && $user) {
        $self->_result()->{user} = $user;

        # Preselect tenant, for now we just pick the first from the list
        if ($user->{tenant}) {
            $self->_result()->{tenant} = $user->{tenant}->[0]->{value};
            $self->logger()->trace('Preset tenant from items ' . Dumper $user->{tenant}) if $self->logger->is_trace;
        }

        my $menu = $self->send_command_v2( 'get_menu' );
        $self->logger()->trace('Menu ' . Dumper $menu) if $self->logger->is_trace;

        $self->_result()->{structure} = $menu->{main};

        # persist the optional parts of the menu hash (landmark, tasklist, search attribs)
        $session->param('landmark', $menu->{landmark} || {});
        $self->logger->trace('Got landmarks: ' . Dumper $menu->{landmark}) if $self->logger->is_trace;

        # tasklist, wfsearch, certsearch and bulk can have multiple branches
        # using named keys. We try to autodetect legacy formats and map
        # those to a "default" key

        # config items are a list of hashes
        foreach my $key (qw(tasklist bulk)) {

            if (ref $menu->{$key} eq 'ARRAY') {
                $session->param($key, { 'default' => $menu->{$key} });
            } elsif (ref $menu->{$key} eq 'HASH') {
                $session->param($key, $menu->{$key} );
            } else {
                $session->param($key, { 'default' => [] });
            }
            $self->logger->trace("Got $key: " . Dumper $menu->{$key}) if $self->logger->is_trace;
        }

        # top level is a hash that must have a "attributes" node
        # legacy format was a single list of attributes
        foreach my $key (qw(wfsearch certsearch)) {

            # plain attributes
            if (ref $menu->{$key} eq 'ARRAY') {
                $session->param($key, { 'default' => { attributes => $menu->{$key} } } );
            } elsif (ref $menu->{$key} eq 'HASH') {
                $session->param($key, $menu->{$key} );
            } else {
                $session->param($key, { 'default' => {} });
            }
            $self->logger->trace("Got $key: " . Dumper $menu->{$key}) if $self->logger->is_trace;
        }

        # Check syntax of "certdetails".
        # (a sub{} allows using return instead of nested if-structures)
        my $certdetails = sub {
            my $result;
            unless ($result = $menu->{certdetails}) {
                $self->logger->warn('Config entry "certdetails" is empty');
                return {};
            }
            unless (ref $result eq 'HASH') {
                $self->logger->warn('Config entry "certdetails" is not a hash');
                return {};
            }
            if ($result->{metadata}) {
                if (ref $result->{metadata} eq 'ARRAY') {
                    for my $md (@{ $result->{metadata} }) {
                        if (not ref $md eq 'HASH') {
                            $self->logger->warn('Config entry "certdetails.metadata" contains an item that is not a hash');
                            $result->{metadata} = [];
                            last;
                        }
                    }
                }
                else {
                    $self->logger->warn('Config entry "certdetails.metadata" is not an array');
                    $result->{metadata} = [];
                }
            }
            return $result;
        }->();
        $session->param('certdetails', $certdetails);

        # Check syntax of "wfdetails".
        # (a sub{} allows using return instead of nested if-structures)
        my $wfdetails = sub {
            if (not exists $menu->{wfdetails}) {
                $self->logger->debug('Config entry "wfdetails" is not defined, using defaults');
                return [];
            }
            my $result;
            unless ($result = $menu->{wfdetails}) {
                $self->logger->debug('Config entry "wfdetails" is set to "undef", hide from output');
                return;
            }
            unless (ref $result eq 'ARRAY') {
                $self->logger->warn('Config entry "wfdetails" is not an array');
                return [];
            }
            return $result;
        }->();
        $session->param('wfdetails', $wfdetails);

        # Ping endpoint
        if ($menu->{ping}) {
            my $ping;
            if (ref $menu->{ping} eq 'HASH') {
                $ping = $menu->{ping};
                $ping->{timeout} *= 1000; # timeout is expected in ms
            } else {
                $ping = { href => $menu->{ping}, timeout => 120000 };
            }
            $self->_result()->{ping} = $ping;
        }

        # Redirection targets for apache based SSO Handling
        if (my $auth = $session->param('authinfo')) {
            if (my $target = ($auth->{resume} || $auth->{login})) {
                $self->_result()->{on_exception} = [{
                    status_code => [ 403, 401 ],
                    redirect => $target,
                }];
            }
        }
    }

    $session->flush();

    if (!$self->_result()->{structure}) {
        $self->_result()->{structure} =
        [{
            key => 'logout',
            label =>  'I18N_OPENXPKI_UI_CLEAR_LOGIN',
            entries =>  []
        }];
    }

    return $self;

}


sub init_error {

    my $self = shift;
    my $args = shift;

    $self->_result()->{main} = [{
        type => 'text',
        content => {
            headline => 'I18N_OPENXPKI_UI_OOPS',
            paragraphs => [{text=>'I18N_OPENXPKI_UI_OOPS'}]
        }
    }];

    return $self;
}
1;
