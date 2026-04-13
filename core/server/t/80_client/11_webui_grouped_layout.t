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

use YAML::PP;
use OpenXPKI::Client::Service::WebUI::Auth;

my $ypp = YAML::PP->new;

# ---------------------------------------------------------------------------
# make_auth - build a minimal Auth stub for testing _realm_selection_grouped_layout
#
# Receives a single YAML string that decodes to a mapping with keys:
#   groups     - sequence of group config mappings. Default: []
#   maxcol     - global maxcol (default 6)
#   realm_mode - 'select' (default) or 'path'
#
# Returns ($auth, $captured, $webui) where $captured is an arrayref that
# receives { flat_tiles => [...], maxcol => N } on each call to
# init_realm_selection. $webui must be held by the caller for the duration
# of the test (Auth stores it as a weak ref).
# ---------------------------------------------------------------------------

sub make_auth {
    my ($yaml) = @_;
    my $cfg = $ypp->load_string($yaml);

    my $groups     = $cfg->{groups}     // [];
    my $maxcol     = $cfg->{maxcol}     // 6;
    my $realm_mode = $cfg->{realm_mode} // 'select';

    my $webui_pkg = 'OpenXPKI::Client::Service::WebUI';

    my $webui = bless {
        _groups     => $groups,
        _maxcol     => $maxcol,
        _realm_mode => $realm_mode,
    }, $webui_pkg;

    my $webui_mock = mock $webui_pkg => set => [
        realm_mode => sub { $_[0]->{_realm_mode} },
    ];

    my $auth = OpenXPKI::Client::Service::WebUI::Auth->new(
        webui => $webui,
        log   => Log::Log4perl->get_logger,
    );

    # Capture calls to init_realm_selection via a stub page_obj
    my @captured;
    my $page_stub = bless { _captured => \@captured }, 'MockPageObj';

    my $page_mock = mock 'MockPageObj' => add => [
        init_realm_selection => sub {
            my ($self, $flat_tiles, $mc) = @_;
            push @{ $self->{_captured} }, { flat_tiles => $flat_tiles, maxcol => $mc };
            return $self;
        },
    ];

    my $auth_mock = mock $auth => set => [
        page_obj                   => sub { $page_stub },
        realm_selection_layout     => sub { 'grouped' },
        realm_selection_groups     => sub { $groups },
        realm_selection_group_cols => sub { $maxcol },
    ];

    # Keep mocks alive inside the auth object so they aren't GC'd
    $auth->{_webui_mock} = $webui_mock;
    $auth->{_auth_mock}  = $auth_mock;
    $auth->{_page_mock}  = $page_mock;

    # Return $webui alongside $auth: Auth stores webui as a weak ref and it
    # will be garbage collected if the caller does not hold a strong reference.
    return ($auth, \@captured, $webui);
}

# Call _realm_selection_grouped_layout and return (flat_tiles, maxcol)
sub run_layout {
    my ($auth, $captured, $realms) = @_;
    $auth->_realm_selection_grouped_layout($realms // {});
    return ($captured->[-1]->{flat_tiles}, $captured->[-1]->{maxcol});
}

# Split the flat tile list on 'newline' sentinels into rows
sub split_into_rows {
    my ($flat) = @_;
    my @rows;
    my @cur;
    for my $t (@{$flat}) {
        if (!ref $t && $t eq 'newline') {
            push @rows, [@cur];
            @cur = ();
        } else {
            push @cur, $t;
        }
    }
    push @rows, [@cur] if @cur;
    return @rows;
}

# Return only non-empty tiles from a row
sub real_tiles {
    my ($row) = @_;
    return grep { ref $_ && $_->{type} ne 'empty' } @{$row};
}

# ---------------------------------------------------------------------------
# Realm data reused across tests
# ---------------------------------------------------------------------------

my $REALMS = {
    realm_a => { LABEL => 'Realm A', DESCRIPTION => 'Desc A', IMAGE => undef, AUTH_STACKS => {} },
    realm_b => { LABEL => 'Realm B', DESCRIPTION => 'Desc B', IMAGE => undef, AUTH_STACKS => {} },
    realm_c => { LABEL => 'Realm C', DESCRIPTION => 'Desc C', IMAGE => undef, AUTH_STACKS => {} },
    realm_d => { LABEL => 'Realm D', DESCRIPTION => 'Desc D', IMAGE => undef, AUTH_STACKS => {} },
    realm_e => { LABEL => 'Realm E', DESCRIPTION => 'Desc E', IMAGE => undef, AUTH_STACKS => {} },
};

# ---------------------------------------------------------------------------
# Single group, no text, select mode
# ---------------------------------------------------------------------------

subtest 'single group, 2 realms, no text - one row of 2 button tiles' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: realm_a
              - target: realm_b
        YAML
    my ($flat, $maxcol) = run_layout($auth, $captured, $REALMS);

    is $maxcol, 6, 'maxcol passed through';

    my @rows = split_into_rows($flat);
    is scalar @rows, 1, 'one row';

    my @real = real_tiles($rows[0]);
    is scalar @real, 2,            'two real tiles';
    is $real[0]->{type},  'button', 'first tile is button';
    is $real[0]->{label}, 'Realm A', 'first tile label';
    is $real[1]->{label}, 'Realm B', 'second tile label';
    is $real[0]->{content}->{action}, 'login!realm', 'action set';
    is $real[0]->{content}->{action_params}->{pki_realm}, 'realm_a', 'pki_realm param';
};

# ---------------------------------------------------------------------------
# Single group with text heading
# ---------------------------------------------------------------------------

subtest 'single group with text - first row is text tile, second row is realm tiles' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - description: My Group
            items:
              - target: realm_a
              - target: realm_b
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    is scalar @rows, 2, 'two rows (text + realms)';

    my ($text_tile) = real_tiles($rows[0]);
    is $text_tile->{type},                   'text',     'text tile type';
    is $text_tile->{border},                 0,          'text tile has border:0';
    is $text_tile->{content}->{description}, 'My Group', 'text tile description';
    is $text_tile->{colspan},                2,          'text tile colspan = group width (2)';

    my @real = real_tiles($rows[1]);
    is scalar @real, 2, 'two realm tiles';
};

# ---------------------------------------------------------------------------
# Two groups fitting in the same band (2+3 <= 6)
# ---------------------------------------------------------------------------

subtest 'two groups fitting in one band (2+3 <= 6) - share same row band' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - description: Group 1
            items:
              - target: realm_a
              - target: realm_b
          - description: Group 2
            items:
              - target: realm_c
              - target: realm_d
              - target: realm_e
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    # text row + realm row = 2 rows total
    is scalar @rows, 2, 'two rows (shared text row + shared realm row)';

    my @text_tiles = real_tiles($rows[0]);
    is scalar @text_tiles, 2,           'two text tiles in text row';
    is $text_tiles[0]->{colspan}, 2,    'first text tile colspan = 2';
    is $text_tiles[1]->{colspan}, 3,    'second text tile colspan = 3';

    my @realm_tiles = real_tiles($rows[1]);
    is scalar @realm_tiles, 5,          'five realm tiles in shared realm row';
};

# ---------------------------------------------------------------------------
# Two groups that do NOT fit - second wraps to new band (4+3 > 6)
# ---------------------------------------------------------------------------

subtest 'two groups not fitting in one band (4+3 > 6) - second group in new band' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - description: Group A
            items:
              - target: realm_a
              - target: realm_b
              - target: realm_c
              - target: realm_d
          - description: Group B
            items:
              - target: realm_e
              - target: realm_a
              - target: realm_b
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    # Band 1: text row + realm row (no trailing newline after realm row)
    # Band 2: inter-band newline merges with band-2 text newline -> text row + realm row
    # Total: 4 rows
    is scalar @rows, 4, 'four rows: text+realms band1, text+realms band2';

    my @b1_text = real_tiles($rows[0]);
    is scalar @b1_text, 1,                               'band 1: one text tile';
    is $b1_text[0]->{colspan}, 4,                        'band 1: text tile colspan = 4';
    is $b1_text[0]->{content}->{description}, 'Group A', 'band 1: text content';

    my @b2_text = real_tiles($rows[2]);
    is scalar @b2_text, 1,                               'band 2: one text tile';
    is $b2_text[0]->{colspan}, 3,                        'band 2: text tile colspan = 3';
    is $b2_text[0]->{content}->{description}, 'Group B', 'band 2: text content';
};

# ---------------------------------------------------------------------------
# item colspan
# ---------------------------------------------------------------------------

subtest 'item colspan widens tile and counts toward group width' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: realm_a
                colspan: 2
              - target: realm_b
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    # Backend emits the two tiles flat; the Tiles component pads to maxcol.
    # Group width = 3 (2+1), so the backend does not emit any empty padding
    # between groups - that is the Tiles component's responsibility.
    my @rows = split_into_rows($flat);
    my @real = real_tiles($rows[0]);
    is scalar @real, 2,        'two real tiles emitted';
    is $real[0]->{colspan}, 2, 'first tile colspan = 2';
    is $real[1]->{colspan}, 1, 'second tile colspan = 1';
};

# ---------------------------------------------------------------------------
# colspan clamped to maxcol
# ---------------------------------------------------------------------------

subtest 'item colspan clamped to maxcol' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 4
        groups:
          - items:
              - target: realm_a
                colspan: 99
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    my ($tile) = real_tiles($rows[0]);
    is $tile->{colspan}, 4, 'colspan clamped to maxcol=4';
};

# ---------------------------------------------------------------------------
# newline sentinel in items list
# ---------------------------------------------------------------------------

subtest 'newline in items forces row break within group' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: realm_a
              - target: realm_b
              - newline
              - target: realm_c
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    # group width = 2 (max row width: row 0 has realm_a+realm_b=2, row 1 has realm_c=1)
    # newline splits: realm_a+realm_b on row 0, realm_c on row 1
    my @rows = split_into_rows($flat);
    is scalar @rows, 2, 'two realm rows due to newline';

    my @row0 = real_tiles($rows[0]);
    my @row1 = real_tiles($rows[1]);
    is scalar @row0, 2, 'two tiles in first row';
    is scalar @row1, 1, 'one tile in second row';
    is $row0[0]->{label}, 'Realm A', 'row 0 tile 0 is Realm A';
    is $row0[1]->{label}, 'Realm B', 'row 0 tile 1 is Realm B';
    is $row1[0]->{label}, 'Realm C', 'row 1 tile 0 is Realm C';
};

# ---------------------------------------------------------------------------
# group with only newlines is skipped
# ---------------------------------------------------------------------------

subtest 'group with only-newline items but with text - shows text heading, no warning' => sub {
    my @warnings;
    my $log = Log::Log4perl->get_logger;
    my $log_mock = mock $log => set => [
        warn => sub { push @warnings, $_[1] },
    ];

    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - description: Empty Group
            items:
              - newline
              - newline
          - items:
              - target: realm_a
        YAML
    $auth->{log} = $log;

    my ($flat) = run_layout($auth, $captured, $REALMS);

    is scalar @warnings, 0, 'no warning emitted for text-only group';

    my @rows = split_into_rows($flat);
    # text row (text tile + button tile), realm row (button tile)
    my @text_tiles  = grep { ref $_ && $_->{type} eq 'text'   } map { @{$_} } @rows;
    my @btn_tiles   = grep { ref $_ && $_->{type} eq 'button' } map { @{$_} } @rows;
    is scalar @text_tiles, 1, 'one text tile for the text-only group';
    is $text_tiles[0]->{content}->{description}, 'Empty Group', 'text tile description';
    is scalar @btn_tiles,  1, 'one button tile for the valid group';
};

# ---------------------------------------------------------------------------
# unknown realm name is skipped with a warning
# ---------------------------------------------------------------------------

subtest 'item referencing unknown realm is skipped with a warning' => sub {
    my @warnings;
    my $log = Log::Log4perl->get_logger;
    my $log_mock = mock $log => set => [
        warn => sub { push @warnings, $_[1] },
    ];

    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: no_such_realm
              - target: realm_a
        YAML
    $auth->{log} = $log;

    my ($flat) = run_layout($auth, $captured, $REALMS);

    ok scalar @warnings > 0, 'warning emitted for unknown realm';
    like $warnings[0], qr/no_such_realm/, 'warning names the offending realm';

    my @rows = split_into_rows($flat);
    my @real = real_tiles($rows[0]);
    is scalar @real, 1,          'only the valid tile appears';
    is $real[0]->{label}, 'Realm A', 'valid tile is realm_a';
};

# ---------------------------------------------------------------------------
# Only one group in a shared band has text
# ---------------------------------------------------------------------------

subtest 'only one group in shared band has text - other group gets empty placeholder' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - description: Has Text
            items:
              - target: realm_a
              - target: realm_b
          - items:
              - target: realm_c
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    is scalar @rows, 2, 'two rows (text + realms)';

    is $rows[0]->[0]->{type},    'text',  'first cell in text row is text tile';
    is $rows[0]->[1]->{type},    'empty', 'second cell in text row is empty placeholder';
    is $rows[0]->[1]->{colspan}, 1,       'empty placeholder spans the group width (1)';
};

# ---------------------------------------------------------------------------
# cssClass derived from realm name
# ---------------------------------------------------------------------------

subtest 'cssClass is derived from realm name' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: My Realm_01
        YAML
    my $realms = {
        'My Realm_01' => { LABEL => 'Test', DESCRIPTION => '', IMAGE => undef, AUTH_STACKS => {} },
    };
    my ($flat) = run_layout($auth, $captured, $realms);

    my @rows = split_into_rows($flat);
    my ($tile) = real_tiles($rows[0]);
    is $tile->{cssClass}, 'oxi-realm-tile-my-realm-01', 'cssClass sanitized correctly';
};

# ---------------------------------------------------------------------------
# label / description / icon overrides
# ---------------------------------------------------------------------------

subtest 'item-level label and description override realm defaults' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: realm_a
                label: Custom Label
                description: Custom Desc
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    my ($tile) = real_tiles($rows[0]);
    is $tile->{label},       'Custom Label', 'label overridden';
    is $tile->{description}, 'Custom Desc',  'description overridden';
};

subtest 'item-level icon suppresses image' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: realm_a
                icon: bi-shield
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    my ($tile) = real_tiles($rows[0]);
    is $tile->{content}->{icon}, 'bi-shield', 'icon set';
    ok !exists $tile->{content}->{image},      'image suppressed when icon present';
};

# ---------------------------------------------------------------------------
# group wider than maxcol overflows to multiple rows
# ---------------------------------------------------------------------------

subtest 'group wider than maxcol - all tiles emitted flat, maxcol passed to frontend' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 3
        groups:
          - items:
              - target: realm_a
              - target: realm_b
              - target: realm_c
              - target: realm_d
              - target: realm_e
        YAML
    my ($flat, $maxcol) = run_layout($auth, $captured, $REALMS);

    is $maxcol, 3, 'maxcol=3 passed to frontend (Tiles component wraps there)';

    # Backend emits all 5 tiles in a single flat list without row breaks;
    # the Tiles component wraps at maxcol=3.
    my @rows = split_into_rows($flat);
    is scalar @rows, 1, 'one flat row emitted by backend';
    my @real = real_tiles($rows[0]);
    is scalar @real, 5, 'all five tiles present';
};

# ---------------------------------------------------------------------------
# "newline" group sentinel fills remaining columns in the row band
# ---------------------------------------------------------------------------

subtest 'newline group sentinel expands preceding group to fill remaining columns' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: realm_a
              - target: realm_b
          - newline
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    is scalar @rows, 1, 'one row';

    # Group has 2 real tiles + 4 empty columns of padding (newline fills to 6)
    my @real  = real_tiles($rows[0]);
    my @empty = grep { ref $_ && $_->{type} eq 'empty' } @{$rows[0]};
    is scalar @real, 2, 'two real tiles';
    my $empty_span = 0;
    $empty_span += $_->{colspan} for @empty;
    is $empty_span, 4, 'empty padding fills remaining 4 columns';
};

subtest 'newline group sentinel alongside a normal group - last group gets spare columns' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - items:
              - target: realm_a
          - items:
              - target: realm_b
              - target: realm_c
          - newline
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    is scalar @rows, 1, 'both groups fit in one row';

    # Group 1: width=1. Group 2: width=2, newline fills to 5.
    # Total occupied = 1+5 = 6 = maxcol.
    my @real = real_tiles($rows[0]);
    is scalar @real, 3, 'three real tiles';

    # The empty padding within the last group should total 3 (5-2)
    my @empty = grep { ref $_ && $_->{type} eq 'empty' } @{$rows[0]};
    my $empty_span = 0;
    $empty_span += $_->{colspan} for @empty;
    is $empty_span, 3, 'last group padded with 3 empty columns';
};

# ---------------------------------------------------------------------------
# text-only group (no items): auto-stretch fills full row width
# ---------------------------------------------------------------------------

subtest 'text-only group without items auto-stretches to full row' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - description: Header Only
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    is scalar @rows, 1, 'one row';

    my ($text_tile) = grep { ref $_ && $_->{type} eq 'text' } @{$rows[0]};
    ok $text_tile, 'text tile present';
    is $text_tile->{colspan}, 6, 'text tile spans full maxcol width';
};

subtest 'text-only group followed by realm group - text occupies full first band' => sub {
    my ($auth, $captured, $webui) = make_auth(<<~'YAML');
        maxcol: 6
        groups:
          - description: Section Header
          - items:
              - target: realm_a
              - target: realm_b
              - target: realm_c
        YAML
    my ($flat) = run_layout($auth, $captured, $REALMS);

    my @rows = split_into_rows($flat);
    # text-only group fills one full band (text row only, no realm row)
    # realm group is in the next band (text row absent, realm row with 3 tiles)
    # inter-band newline separates them
    # -> row 0: text tile (colspan=6), row 1: 3 buttons
    is scalar @rows, 2, 'two rows: text band then realm band';

    my ($text_tile) = grep { ref $_ && $_->{type} eq 'text' } @{$rows[0]};
    is $text_tile->{colspan}, 6, 'text tile spans full width';
    is $text_tile->{content}->{description}, 'Section Header', 'text content correct';

    my @btn = real_tiles($rows[1]);
    is scalar @btn, 3, 'three realm buttons in second band';
};

done_testing;
