# OpenXPKI::Client::UI::Bootstrap
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bootstrap;

use Moose;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use OpenXPKI::i18n qw( i18nTokenizer );

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

    if ($session->param('is_logged_in') && $user) {
        $self->_result()->{user} = $user;
        my $menu = $self->send_command( 'get_menu' );
        $self->logger()->trace('Menu ' . Dumper $menu);

        $self->_result()->{structure} = $menu->{main};

        # persist the optional parts of the menu hash (landmark, tasklist, search attribs)
        $session->param('landmark', $menu->{landmark} || {});
        $self->logger->trace('Got landmarks: ' . Dumper $menu->{landmark});

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
            $self->logger->trace("Got $key: " . Dumper $menu->{$key});
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
            $self->logger->trace("Got $key: " . Dumper $menu->{$key});
        }

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

    }

    # To issue redirects to the UI, we store the referrer
    # default is mainly relevant for test scripts
    my $baseurl = $self->param('baseurl') || '/openxpki';
    $baseurl =~ s|/$||;
    $session->param('baseurl',  $baseurl.'/#/');
    $self->logger->debug("Baseurl from referrer: " . $baseurl);

    if (!$self->_result()->{structure}) {
        $self->_result()->{structure} =
        [{
            key => 'logout',
            label =>  'Clear Login',
            entries =>  []
        }]
    }

    return $self;

}


sub init_error {

    my $self = shift;
    my $args = shift;

    $self->_result()->{main} = [{
        type => 'text',
        content => {
            headline => 'Ooops - something went wrong',
            paragraphs => [{text=>'Something is wrong here'}]
        }
    }];

    return $self;
}
1;
