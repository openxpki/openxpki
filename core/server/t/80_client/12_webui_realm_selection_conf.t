#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";

# CPAN modules
use Test2::V0;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({ level => $ENV{TEST_VERBOSE} ? $DEBUG : $OFF, layout => '# %m%n' });

use OpenXPKI::Client::Service::WebUI;
use OpenXPKI::Client::Service::WebUI::Auth;

# ---------------------------------------------------------------------------
# make_webui - minimal WebUI stub with a config that handles both:
#   get('dot.path')                        - scalar lookup
#   get_hash(['realm','selection','page']) - arrayref key lookup
#
# Named arguments:
#   config_scalar - hashref: dot-path string -> scalar value
#   config_hash   - hashref: dot-path string -> hashref value
# ---------------------------------------------------------------------------

sub make_webui {
    my (%args) = @_;

    my $scalar_cfg = $args{config_scalar} // {};
    my $hash_cfg   = $args{config_hash}   // {};

    my $config = mock {} => add => [
        get => sub {
            my ($self, $key) = @_;
            $key = join('.', @$key) if ref $key eq 'ARRAY';
            return $scalar_cfg->{$key};
        },
        get_hash => sub {
            my ($self, $key) = @_;
            $key = join('.', @$key) if ref $key eq 'ARRAY';
            return $hash_cfg->{$key};
        },
    ];

    my $webui_pkg = 'OpenXPKI::Client::Service::WebUI';
    my $webui = bless { _config => $config }, $webui_pkg;

    $webui->{_mock_ctrl} = mock $webui_pkg => set => [
        config => sub { $_[0]->{_config} },
    ];

    return $webui;
}

sub make_auth {
    my ($webui) = @_;
    return OpenXPKI::Client::Service::WebUI::Auth->new(
        webui => $webui,
        log   => Log::Log4perl->get_logger,
    );
}

# ---------------------------------------------------------------------------
# realm_selection_page / is_realm_selection_page
# ---------------------------------------------------------------------------

subtest 'realm_selection_page - predicate is false before assignment' => sub {
    my $webui = make_webui();
    ok !$webui->is_realm_selection_page, 'predicate false before assignment';
};

subtest 'realm_selection_page - predicate is true after assignment' => sub {
    my $webui = make_webui();
    $webui->realm_selection_page('default');
    ok $webui->is_realm_selection_page, 'predicate true after assignment';
    is $webui->realm_selection_page, 'default', 'page name is "default"';
};

subtest 'realm_selection_page - named page sets correct page name' => sub {
    my $webui = make_webui();
    $webui->realm_selection_page('partner');
    is $webui->realm_selection_page, 'partner', 'page name is "partner"';
};

# ---------------------------------------------------------------------------
# realm_selection_conf - config key lookup by page name
# ---------------------------------------------------------------------------

subtest 'realm_selection_conf - reads realm.selection.default config hash' => sub {
    my $webui = make_webui(
        config_hash => { 'realm.selection.default' => { layout => 'list' } },
    );
    $webui->realm_selection_page('default');
    is $webui->realm_selection_conf->{layout}, 'list', 'layout from realm.selection.default';
};

subtest 'realm_selection_conf - reads realm.selection.PAGE for a named page' => sub {
    my $webui = make_webui(
        config_hash => { 'realm.selection.partner' => { layout => 'grouped', cols => 4 } },
    );
    $webui->realm_selection_page('partner');
    my $conf = $webui->realm_selection_conf;
    is $conf->{layout}, 'grouped', 'layout from realm.selection.partner';
    is $conf->{cols},   4,         'cols from realm.selection.partner';
};

subtest 'realm_selection_conf - "default" and named page use separate config keys' => sub {
    my $webui_default = make_webui(
        config_hash => {
            'realm.selection.default' => { layout => 'card' },
            'realm.selection.partner' => { layout => 'list' },
        },
    );
    $webui_default->realm_selection_page('default');
    is $webui_default->realm_selection_conf->{layout}, 'card', 'default page -> card layout';

    my $webui_partner = make_webui(
        config_hash => {
            'realm.selection.default' => { layout => 'card' },
            'realm.selection.partner' => { layout => 'list' },
        },
    );
    $webui_partner->realm_selection_page('partner');
    is $webui_partner->realm_selection_conf->{layout}, 'list', 'partner page -> list layout';
};

# ---------------------------------------------------------------------------
# realm_selection_conf - legacy config fallback chain
# ---------------------------------------------------------------------------

subtest 'realm_selection_conf - falls back to realm.layout when no selection config' => sub {
    my $webui = make_webui(
        config_scalar => { 'realm.layout' => 'list' },
    );
    $webui->realm_selection_page('default');
    is $webui->realm_selection_conf->{layout}, 'list', 'layout from realm.layout';
};

subtest 'realm_selection_conf - falls back to global.realm_layout when realm.layout absent' => sub {
    my $webui = make_webui(
        config_scalar => { 'global.realm_layout' => 'grouped' },
    );
    $webui->realm_selection_page('default');
    is $webui->realm_selection_conf->{layout}, 'grouped', 'layout from global.realm_layout';
};

subtest 'realm_selection_conf - defaults to "card" when no config at all' => sub {
    my $webui = make_webui();
    $webui->realm_selection_page('default');
    is $webui->realm_selection_conf->{layout}, 'card', 'layout defaults to "card"';
};

subtest 'realm_selection_conf - realm.selection.PAGE.layout overrides legacy realm.layout' => sub {
    my $webui = make_webui(
        config_hash   => { 'realm.selection.default' => { layout => 'grouped' } },
        config_scalar => { 'realm.layout' => 'list' },
    );
    $webui->realm_selection_page('default');
    is $webui->realm_selection_conf->{layout}, 'grouped',
        'explicit selection config wins over legacy realm.layout';
};

# ---------------------------------------------------------------------------
# Auth attributes derived from realm_selection_conf
# ---------------------------------------------------------------------------

subtest 'Auth realm_selection_layout - reads layout from webui realm_selection_conf' => sub {
    my $webui = make_webui(
        config_hash => { 'realm.selection.default' => { layout => 'list' } },
    );
    $webui->realm_selection_page('default');
    my $auth = make_auth($webui);
    is $auth->realm_selection_layout, 'list', 'realm_selection_layout is "list"';
};

subtest 'Auth realm_selection_groups - empty arrayref when layout is not grouped' => sub {
    my $webui = make_webui(
        config_hash => { 'realm.selection.default' => { layout => 'card' } },
    );
    $webui->realm_selection_page('default');
    my $auth = make_auth($webui);
    is $auth->realm_selection_groups, [], 'groups empty for card layout';
};

subtest 'Auth realm_selection_groups - returns groups list when layout is grouped' => sub {
    my $groups = [ { label => 'Group A', realms => ['ca1'] }, { label => 'Group B', realms => ['ca2'] } ];
    my $webui = make_webui(
        config_hash => {
            'realm.selection.default' => { layout => 'grouped', groups => $groups },
        },
    );
    $webui->realm_selection_page('default');
    my $auth = make_auth($webui);
    is $auth->realm_selection_groups, $groups, 'groups list returned for grouped layout';
};

subtest 'Auth realm_selection_group_cols - returns -1 when layout is not grouped' => sub {
    my $webui = make_webui(
        config_hash => { 'realm.selection.default' => { layout => 'list' } },
    );
    $webui->realm_selection_page('default');
    my $auth = make_auth($webui);
    is $auth->realm_selection_group_cols, -1, 'cols -1 for non-grouped layout';
};

subtest 'Auth realm_selection_group_cols - defaults to 6 for grouped layout without cols' => sub {
    my $webui = make_webui(
        config_hash => { 'realm.selection.default' => { layout => 'grouped' } },
    );
    $webui->realm_selection_page('default');
    my $auth = make_auth($webui);
    is $auth->realm_selection_group_cols, 6, 'cols defaults to 6 for grouped layout';
};

subtest 'Auth realm_selection_group_cols - reads explicit cols value from config' => sub {
    my $webui = make_webui(
        config_hash => { 'realm.selection.default' => { layout => 'grouped', cols => 4 } },
    );
    $webui->realm_selection_page('default');
    my $auth = make_auth($webui);
    is $auth->realm_selection_group_cols, 4, 'cols taken from config';
};

subtest 'Auth attributes for named page - independent from default page config' => sub {
    my $groups = [ { label => 'Partner group', realms => ['partner-ca'] } ];
    my $webui = make_webui(
        config_hash => {
            'realm.selection.default' => { layout => 'card' },
            'realm.selection.partner' => { layout => 'grouped', cols => 3, groups => $groups },
        },
    );
    $webui->realm_selection_page('partner');
    my $auth = make_auth($webui);
    is $auth->realm_selection_layout,     'grouped', 'partner page layout is grouped';
    is $auth->realm_selection_group_cols, 3,         'partner page cols is 3';
    is $auth->realm_selection_groups,     $groups,   'partner page groups returned';
};

done_testing;
