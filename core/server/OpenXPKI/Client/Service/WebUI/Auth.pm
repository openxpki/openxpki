package OpenXPKI::Client::Service::WebUI::Auth;

=head1 NAME

OpenXPKI::Client::Service::WebUI::Auth - Authentication and session management for the WebUI service

=head1 SYNOPSIS

    my $auth = OpenXPKI::Client::Service::WebUI::Auth->new(
        webui => $webui,
    );

    # One login step; returns a page object or undef when done
    my $page = $auth->login($page, $action, $last_server_reply);

    # Handle logout
    my $page = $auth->logout($page);

=head1 DESCRIPTION

Handles the complete authentication lifecycle for the WebUI: initial login
redirects, realm and auth-stack selection, credential submission for all
supported login types (password, X.509 certificate, SSO/client, OIDC), logout,
and post-login session setup (menu, MOTD, search config).

It is constructed by L<OpenXPKI::Client::Service::WebUI> and called from the
dispatcher on every request that arrives before or during the login sequence.

=cut

use OpenXPKI qw( -class -typeconstraints );

# Core modules
use Encode;
use List::Util qw( min max any );
use MIME::Base64 qw( encode_base64 decode_base64 );

# CPAN modules
use Crypt::JWT qw( encode_jwt decode_jwt );
use URI::Escape;

# Project modules
use OpenXPKI::Client::Service::WebUI::Page::Login;
use OpenXPKI::Template;
use OpenXPKI::Dumper;

=head1 ATTRIBUTES

=head2 webui

The parent L<OpenXPKI::Client::Service::WebUI> instance. Required; stored as a
weak reference to avoid circular ownership.

=cut
has webui => (
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI',
    required => 1,
    weak_ref => 1,
);

=head2 log

Logger object. Defaults to C<OpenXPKI::Log4perl-E<gt>get_logger>.

=cut
has log => (
    is => 'rw',
    isa => duck_type( [qw(
           trace    debug    info    warn    error    fatal
        is_trace is_debug is_info is_warn is_error is_fatal
    )] ),
    lazy => 1,
    default => sub { OpenXPKI::Log4perl->get_logger },
);

=head2 login_page

Internal login page name, read from C<login.page> (or the legacy key
C<global.loginpage>) in the WebUI service config. Empty string when not set.
Auto-initialized.

=cut
has login_page => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->webui->config->get('login.page') || $self->webui->config->get('global.loginpage') // '' },
);

=head2 login_url

External login redirect URL, read from C<login.url> (or the legacy key
C<global.loginurl>) in the WebUI service config. Empty string when not set.
Auto-initialized.

=cut
has login_url => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub ($self) { $self->webui->config->get('login.url') || $self->webui->config->get('global.loginurl') // '' },
);

=head2 jwt_key

DER-encoded EC public key (I<Str>) used to sign non-password auth requests via
JWT. Read from config key C<auth.sign.key> (base64-encoded). C<undef> when not
configured. Auto-initialized.

=cut
has jwt_key => (
    init_arg => undef,
    is => 'ro',
    isa => 'Str|Undef',
    lazy => 1,
    default => sub ($self) {
        # TODO Rework auth.sign.key handling
        # The key is used to sign non-password auth requests.
        # Create the key using "openssl ecparam -name secp256r1 -genkey -noout"
        # Put the public key into auth/stack.yaml where required.
        my $key = $self->webui->config->get(['auth', 'sign.key']) or return undef;
        return decode_base64($key);
    },
);

=head2 realm_path_map

Only used when C<realm_mode=path>. A HashRef mapping each realm name to an
ArrayRef of C<{ url =E<gt> ..., stack =E<gt> ... }> entries, one per URL alias
defined in C<realm.map> (or the legacy C<realm> key) in the service config.
Built lazily from the config on first access. Auto-initialized.

=cut
has realm_path_map => (
    init_arg => undef,
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_realm_path_map',
);
sub _build_realm_path_map ($self) {
    my $map = {};

    my $realm_map = $self->webui->config->get_hash('realm.map');
    # legacy config
    $realm_map //= $self->webui->config->get_hash('realm');
    for my $url_alias (keys $realm_map->%*) {
        my ($realm, $stack) = split (/\s*;\s*/, $realm_map->{$url_alias});
        $map->{$realm} //= [];
        push $map->{$realm}->@*, {
            url_alias => $url_alias,
            url => $self->webui->url_path_for($url_alias) . '/',
            stack => $stack,
        }
    };
    $self->log->trace('URL path and auth stacks by realm: ' . Dumper($map)) if $self->log->is_trace;
    return $map;
}

=head2 realm_selection_layout

Returns the C<realm.selection.PAGE.layout> config value that defines the layout
of the realm selection: C<"card">, C<"list">, or C<"grouped">. Default: C<"card">.
Auto-initialized.

=cut
has realm_selection_layout => (
    init_arg => undef,
    is => 'ro',
    isa => enum([qw(
        card
        list
        grouped
    )]),
    lazy => 1,
    default => sub ($self) { $self->webui->realm_selection_conf->{layout} },
);

=head2 realm_selection_groups

Returns the C<realm.selection.PAGE.groups> config list if
C<realm.selection.PAGE.layout == "grouped">, an empty I<ArrayRef> otherwise.
Auto-initialized.

=cut
sub realm_selection_groups;
has realm_selection_groups => (
    init_arg => undef,
    is => 'ro',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub ($self) {
        return [] unless $self->realm_selection_layout eq 'grouped';
        return $self->webui->realm_selection_conf->{groups} // [];
    },
);

=head2 realm_selection_group_cols

Global column count for the C<"grouped"> realm selection layout.
Reads the top-level C<cols> key from C<realm.layout>. Default: C<6>.
Returns C<-1> when L</realm_selection_layout> is not C<"grouped">. Auto-initialized.

=cut

sub realm_selection_group_cols;
has realm_selection_group_cols => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'Int',
    lazy     => 1,
    default  => sub ($self) {
        return -1 unless $self->realm_selection_layout eq 'grouped';
        return $self->webui->realm_selection_conf->{cols} // 6;
    },
);

=head2 last_reply

The most recent raw reply HashRef received from
C<$self-E<gt>webui-E<gt>client-E<gt>send_receive_service_msg()>. C<undef> until
the first message exchange. Auto-initialized.

=cut
has last_reply => (
    init_arg => undef,
    is => 'rw',
    isa => 'HashRef|Undef',
    default => undef,
);

=head2 page_obj

Helper that returns a L<OpenXPKI::Client::Service::WebUI::Page::Login> object.
Cleared at the start of each call to C</login> as a guard against multiple calls
within one request. Auto-initialized.

=cut
has page_obj => (
    init_arg => undef,
    is => 'rw',
    isa => 'OpenXPKI::Client::Service::WebUI::Page::Login',
    lazy => 1,
    default => sub ($self) {
        return OpenXPKI::Client::Service::WebUI::Page::Login->new(webui => $self->webui);
    },
    clearer => 'clear_page_obj',
);

=head1 METHODS

=head2 login

Drive one step of the login sequence for the current request. Reads realm and
auth-stack from the session, delegates to the appropriate handler method based
on the server's C<SERVICE_MSG>, and returns a page object.

B<Parameters>

=over

=item * C<$page> I<Str|Undef> - required: page string from the request.

=item * C<$action> I<Str|Undef> - required: action string from the request.

=item * C<$reply> I<HashRef> - required: the most recent reply from the backend
service (i.e. the result of L<OpenXPKI::Client/send_receive_service_msg>).

=back

Returns a L<OpenXPKI::Client::Service::WebUI::Page> page object, or
C<undef> in special cases if the caller should continue without rendering.

=cut

signature_for login => (
    method => 1,
    positional => [
        'Str|Undef', 'Str|Undef', 'HashRef',
    ],
);
sub login ($self, $page, $action, $reply) {
    $page //= '';
    $action //= '';
    $self->last_reply($reply);

    $self->log->info("Not logged in - authenticating; page = '$page', action = '$action'");
    $self->clear_page_obj; # paranoia: guard against multiple calls to login() within one request

    # Read login parameters "pki_realm" and "auth_stack"
    if ($action eq 'login!realm' and my $realm = scalar $self->webui->param('pki_realm')) {
        $self->log->debug("Overwrite realm with '$realm' set via action '$action'");
        $self->webui->session->param('pki_realm', $realm);
        $self->webui->session->param('auth_stack', undef);
    }
    if ($action eq 'login!stack' and my $stack = scalar $self->webui->param('auth_stack')) {
        $self->log->debug("Overwrite auth stack with '$stack' set via action '$action'");
        $self->webui->session->param('auth_stack', $stack);
    }

    my $realm = $self->webui->session->param('pki_realm') || '';
    my $auth_stack =  $self->webui->session->param('auth_stack') || '';

    # If this is an initial request, force redirect to the login page.
    # Does an external redirect if "loginurl" is set in config.
    if ($action !~ /^login/ and $page !~ /^login/) {
        return $self->_handle_redirect($page);
    }

    $self->log->debug(sprintf("Status: '%s'", $self->last_reply->{SERVICE_MSG}));

    # Login usually works in three steps realm -> auth stack -> credentials.
    # If there is only one realm, the server skips the realm selection phase.

    if ($self->last_reply->{SERVICE_MSG} eq 'GET_PKI_REALM') {
        my $result = $self->_handle_GET_PKI_REALM($realm);
        return $result if $result;
    }

    if ($self->last_reply->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK') {
        my $result = $self->_handle_GET_AUTHENTICATION_STACK($auth_stack);
        return $result if $result;
    }

    $self->log->debug(sprintf("Selected realm: '%s', new status: '%s'", $realm, $self->last_reply->{SERVICE_MSG}));
    $self->log->trace('Reply = ' . Dumper $self->last_reply) if $self->log->is_trace;

    # we have more than one login handler and leave it to the login
    # class to render it right.
    if ( $self->last_reply->{SERVICE_MSG} =~ /GET_(.*)_LOGIN/ ) {
        my $type = $1;

        ## FIXME - need a good way to configure login handlers
        $self->log->info('Requested login type ' . $type );
        my $auth = $self->last_reply->{PARAMS};
        my $jws = $self->last_reply->{SIGN};

        return $self->_handle_GET_CLIENT_LOGIN($auth, $jws)                     if 'CLIENT' eq $type;
        return $self->_handle_GET_X509_LOGIN($jws)                              if 'X509' eq $type;
        return $self->_handle_GET_OIDC_LOGIN($page, $auth, $realm, $auth_stack) if 'OIDC' eq $type;
        return $self->_handle_GET_PASSWD_LOGIN($action, $auth, $jws)            if 'PASSWD' eq $type;

        $self->log->warn("Unknown login type '$type'");
    }

    return $self->_check_response;
}

sub _handle_redirect ($self, $page) {
    # Requests to pages can be redirected after login, store page in session
    if ($page and $page ne 'logout' and $page ne 'welcome') {
        $self->log->debug("Store page request in session for later redirect: $page");
        $self->webui->session->param('redirect', $page);
    }

    # Link to an internal method using the class!method
    # FIXME Custom internal login page not working
    if (my $loginpage = $self->login_page) {
        $self->log->debug("Redirect to internal login page: $loginpage");
        return $self->webui->dispatcher->view($loginpage);
    }

    if (my $loginurl = $self->login_url) {
        $self->log->debug("Redirect to external login page: $loginurl");
        $self->page_obj->redirect->external($loginurl);

    } elsif ( $self->webui->request->headers->header('X-OPENXPKI-Client') ) {
        # Session is gone but we are still in the Ember application
        $self->log->debug("Ember UI request with invalid backend session - redirect to login page");
        $self->page_obj->redirect->to('login');

    } else {
        # This is not an Ember request so we need to redirect back to the Ember page
        my $url = $self->webui->base_url . '/#/openxpki/login';
        $self->log->debug('Redirect to login page: ' . $url);
        $self->page_obj->redirect->to($url);
    }

    return $self->page_obj;
}

sub _handle_GET_PKI_REALM ($self, $realm) {
    # store realm in backend session if given
    if ($realm) {
        $self->log->debug("Set chosen pki_realm '$realm' in backend session");
        $self->_send_to_backend( 'GET_PKI_REALM', { PKI_REALM => $realm } );
        return;
    }

    # show realm selection otherwise

    $self->log->debug("No realm chosen, showing realm selection page");

    my $realms = $self->last_reply->{PARAMS}->{PKI_REALMS};

    my $layout = $self->realm_selection_layout;
    # Auto-layout modes "card" and "list"
    if ('card' eq $layout or 'list' eq $layout) {
        return $self->_realm_selection_card_list_layout($realms);

    # Custom layout mode "grouped"
    } elsif ('grouped' eq $layout) {
        return $self->_realm_selection_grouped_layout($realms);

    } else {
        die "Unknown realm selection layout mode '$layout'\n";
    }
}

sub _realm_selection_card_list_layout ($self, $realms) {
    my $css_class_from_realm = sub {
        my $r = lc(shift);
        $r =~ s/[_\s]/-/g;
        $r =~ s/[^a-z0-9-]//g;
        $r =~ s/-+/-/g;
        "oxi-realm-card-$r"
    };

    my @cards;
    # "path" mode: realm cards are links to defined sub paths
    if ('path' eq $self->webui->realm_mode) {
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
                    css_class => $css_class_from_realm->($realm),
                    href => $def->{url},
                };
            }
        }

    # "select" and "hostname" modes: realm cards are actions that set the
    # "pki_realm" parameter. "hostname" mode will only reach this code if the
    # current request's host was not found in `webui.default.realm.map`.
    } else {
        @cards =
            map { {
                label => $realms->{$_}->{LABEL},
                description => $realms->{$_}->{DESCRIPTION},
                image => $realms->{$_}->{IMAGE},
                color => $realms->{$_}->{COLOR},
                css_class => $css_class_from_realm->($_),
                action => 'login!realm',
                action_params => {
                    pki_realm => $realms->{$_}->{NAME},
                },
            } }
            sort { lc($realms->{$a}->{LABEL}) cmp lc($realms->{$b}->{LABEL}) }
            keys %{$realms};
    }

    return $self->page_obj->init_realm_cards(\@cards, $self->realm_selection_layout eq 'list' ? 1 : 0);
}

sub _realm_selection_grouped_layout ($self, $realms) {
    my $maxcol = $self->realm_selection_group_cols;

    my $css_class_from_realm = sub {
        my $r = lc(shift);
        $r =~ s/[_\s]/-/g;
        $r =~ s/[^a-z0-9-]//g;
        $r =~ s/-+/-/g;
        "oxi-realm-tile-$r"
    };

    # Phase 1: build per-group tile data
    my @groups;
    for my $group_def ($self->realm_selection_groups->@*) {
        # A scalar "newline" item marks previous group as "last in row"
        if (not ref $group_def and 'newline' eq $group_def) {
            $groups[-1]->{stretch} = 1 if @groups;
            next;
        }

        my @tiles;
        my $group_width = 0;
        my $row_width = 0;  # width of the current row; group_width = max across all rows
        my $tile_count = 0;

        for my $btn_def ($group_def->{items}->@*) {
            # newline starts a new row; group width is the max of all row widths
            if (not ref $btn_def and 'newline' eq $btn_def) {
                $group_width = max($group_width, $row_width);
                $row_width = 0;
                push @tiles, 'newline';
                next;
            }

            my $target = $btn_def->{target} or next;

            # Path mode: target is a url_alias (key from webui.default.realm.map);
            # realm_path_map is keyed by realm name, with url_alias inside each entry
            my ($realm, $realm_data, $path_def);
            if ('path' eq $self->webui->realm_mode) {
                for my $r (keys $self->realm_path_map->%*) {
                    ($path_def) = grep { $_->{url_alias} eq $target } $self->realm_path_map->{$r}->@*;
                    if ($path_def) { $realm = $r; last }
                }
                if (not $realm) {
                    $self->log->warn("URL path '$target' referenced in realm.layout.group is not defined in realm.map");
                    next;
                }
            } else {
                $realm = $target;
            }
            $realm_data = $realms->{$realm};
            if (not $realm_data) {
                $self->log->warn("Realm '$realm' referenced in realm.layout.group / realm.map not found in server's realm list");
                next;
            }

            # Limit colspan to [1, $maxcol]
            my $colspan = max(1, min($btn_def->{colspan} // 1, $maxcol));

            my $label  = $btn_def->{label}       // $realm_data->{LABEL};
            my $desc   = $btn_def->{description} // $realm_data->{DESCRIPTION};
            my $format = $btn_def->{format};
            my $icon   = $btn_def->{icon};
            my $image  = $icon ? undef : ($btn_def->{image} // $realm_data->{IMAGE});

            my $tile = {
                type     => 'button',
                label    => $label,
                description => $desc,
                cssClass => join(' ', $css_class_from_realm->($realm), $btn_def->{cssClass} // ()),
                colspan  => $colspan,
                content  => {
                    $format ? (format => $format) : (),
                    $icon   ? (icon   => $icon)   : (),
                    $image  ? (image  => $image)  : (),
                },
            };

            # Path mode: one tile for the specific url_alias
            if ('path' eq $self->webui->realm_mode) {
                my $stack = $path_def->{stack};
                my $footer = $btn_def->{footer};
                $footer //= $stack
                    ? ($realm_data->{AUTH_STACKS}->{$stack}
                        ? $realm_data->{AUTH_STACKS}->{$stack}->{label}
                        : $stack)
                    : '';
                $tile->{content}->{href}   = $path_def->{url};
                $tile->{content}->{footer} = $footer if $footer;

            # Select / hostname mode: target is the realm name
            } else {
                $tile->{content}->{action}        = 'login!realm';
                $tile->{content}->{action_params} = { pki_realm => $target };
            }

            push @tiles, $tile;
            $row_width += $colspan;
            $tile_count++;
        }
        $group_width = max($group_width, $row_width);

        my $has_header = length($group_def->{label} // '')
                      || length($group_def->{description} // '');

        if ($tile_count == 0) {
            next unless $has_header;
            # text-only group: no tile items, width resolved during band packing
        }

        push @groups, {
            width       => $group_width,
            label       => $group_def->{label},
            description => $group_def->{description},
            _has_header => $has_header,
            items       => [@tiles],
            # Stretch group to full width if text-only
            stretch     => ($tile_count == 0 ? 1 : 0),
        };
    }

    # Phase 2: pack groups into bands (a band is a horizontal strip of one or
    # more groups placed side by side; groups wrap to a new band when the total
    # width would exceed $maxcol).
    my (@bands, @current_band);
    my $width = 0;

    my $close_band = sub {
        return unless @current_band;
        push @bands, [@current_band];
        @current_band = ();
        $width = 0;
    };

    for my $group (@groups) {
        $close_band->() if $width + $group->{width} > $maxcol;
        push @current_band, $group;
        $width += $group->{width};
        # A stretch group fills the rest of the band and closes it immediately.
        if ($group->{stretch}) {
            $group->{width} += $maxcol - $width;
            $close_band->();
        }
    }
    $close_band->();

    # Phase 3: emit flat tile list from bands
    my @flat_tiles;
    for my $band (@bands) {
        push @flat_tiles, 'newline' if @flat_tiles;

        # Pre-split each group's tiles into rows by accumulating colspans;
        # 'newline' sentinels in the items list force a row break within the group.
        my @group_rows;
        for my $group ($band->@*) {
            my (@rows, @row, $used);
            $used = 0;

            my $flush = sub {
                return unless @row;
                push @row, { type => 'empty', colspan => $group->{width} - $used } if $used < $group->{width};
                push @rows, [@row];
                @row = ();
                $used = 0;
            };

            for my $tile ($group->{items}->@*) {
                if (not ref $tile and 'newline' eq $tile) { $flush->(); next }
                $flush->() if $used + $tile->{colspan} > $group->{width};
                push @row, $tile;
                $used += $tile->{colspan};
                $flush->() if $used >= $group->{width};
            }
            $flush->();
            push @group_rows, \@rows;
        }

        # Text-tile row: only if at least one group in this band has a text heading.
        # The trailing newline is only emitted when tile-content rows follow.
        my $band_height = max(map { scalar $_->@* } @group_rows);
        if (any { $_->{_has_header} } $band->@*) {
            for my $group ($band->@*) {
                push @flat_tiles, $group->{_has_header}
                    ? {
                        type => 'text',
                        colspan => $group->{width},
                        border => 0,
                        cssClass => 'oxi-realm-selection-group-text',
                        content => {
                            label => $group->{label},
                            description => $group->{description},
                        },
                    }
                    : {
                        type => 'empty',
                        colspan => $group->{width},
                    };
            }
            push @flat_tiles, 'newline' if $band_height > 0;
        }

        # column-alignment: pad groups with fewer tile-rows than the tallest in the band
        for my $row_idx (0 .. $band_height - 1) {
            for my $g (0 .. $#{$band}) {
                push @flat_tiles, $row_idx < @{$group_rows[$g]}
                    ? @{$group_rows[$g]->[$row_idx]}
                    : { type => 'empty', colspan => $band->[$g]->{width} };
            }
            push @flat_tiles, 'newline' unless $row_idx == $band_height - 1;
        }
    }

    return $self->page_obj->init_realm_selection(\@flat_tiles, $maxcol);
}

sub _handle_GET_AUTHENTICATION_STACK ($self, $auth_stack) {
    # Only one realm in "path" mode? Redirect to realm URL
    # (server skipped GET_PKI_REALM so we assume there is only one realm)
    if ('path' eq $self->webui->realm_mode and $self->webui->is_realm_selection_page) {

        # fetch realm name
        $self->_send_to_backend('GET_REALM_LIST');
        my $realm_list = $self->last_reply->{PARAMS};

        my $error;
        if (scalar $realm_list->@* == 1) {
            my $realm = $realm_list->[0]->{name};
            if (my $paths = $self->realm_path_map->{$realm}) {
                if (scalar $paths->@* == 1) {
                    my $url = $paths->[0]->{url};
                    $self->log->debug("Only one realm - redirect to: $url");
                    $self->page_obj->redirect->external($url);
                    return $self->page_obj;
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
        $self->page_obj->status->error($error);
        return $self->page_obj;
    }

    # store auth stack in backend session if given
    if ( $auth_stack && $auth_stack !~ /^_/) { # "!~ /^_/" --> Never auth with an internal stack!
        $self->log->debug("Authentication stack: $auth_stack");
        $self->_send_to_backend( 'GET_AUTHENTICATION_STACK', {
            AUTHENTICATION_STACK => $auth_stack
        });

    # show auth stack selection otherwise
    } else {
        my $stacks = $self->last_reply->{'PARAMS'}->{'AUTHENTICATION_STACKS'};

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
            $self->webui->session->param('auth_stack', $auth_stack);
            $self->log->debug("Only one stack available ($auth_stack) - autoselect");
            $self->_send_to_backend( 'GET_AUTHENTICATION_STACK', {
                AUTHENTICATION_STACK => $auth_stack
            } );
        } else {
            $self->log->trace("Offering stacks: " . Dumper \@stack_list ) if $self->log->is_trace;
            return $self->page_obj->init_auth_stack(\@stack_list);
        }
    }
    return;
}

sub _handle_GET_CLIENT_LOGIN ($self, $auth, $jws) {

    # SSO Login uses data from the ENV, so no need to render anything
    $self->log->trace('Available webserver ENV: ' . join(', ', sort keys $self->webui->request->env->%*)) if $self->log->is_trace;
    my $data;
    if ($auth->{envkeys}) {
        foreach my $key (keys %{$auth->{envkeys}}) {
            my $envkey = $auth->{envkeys}->{$key};
            $self->log->debug("Try to load '$key' from webserver ENV '$envkey'");
            next unless defined $self->webui->request->env->{$envkey};
            $data->{$key} = Encode::decode('UTF-8', $self->webui->request->env->{$envkey}, Encode::LEAVE_SRC | Encode::FB_CROAK);
        }
    # legacy support
    } elsif (my $user = $self->webui->request->env->{OPENXPKI_USER} || $self->webui->request->env->{REMOTE_USER}) {
        $data->{username} = $user;
        $data->{role} = $self->webui->request->env->{OPENXPKI_GROUP} if $self->webui->request->env->{OPENXPKI_GROUP};
    }

    # Send login data.
    # At least some items were found, so we send them to the backend.
    if ($data) {
        $self->log->trace('Sending auth data ' . Dumper $data) if $self->log->is_trace;

        $data = $self->_jwt_signature($data, $jws) if ($jws);

        $self->_send_to_backend( 'GET_CLIENT_LOGIN', $data );
        return $self->_check_response;
    }

    # as nothing was found we do not even try to login in and look for a redirect
    if (my $loginurl = $auth->{login}) {

        # the login url might contain a backlink to the running instance
        $loginurl = OpenXPKI::Template->new->render( $loginurl,
            { baseurl => $self->webui->base_url } );

        $self->log->debug("No auth data in environment - redirect found $loginurl");
        $self->page_obj->redirect->external($loginurl);
        return $self->page_obj;

    # bad luck - something seems to be really wrong
    } else {
        $self->log->error('No ENV data to perform SSO Login');
        $self->webui->logout_session;
        return $self->page_obj->init_login_missing_data;
    }
}

sub _handle_GET_X509_LOGIN ($self, $jws) {

    my $user = $self->webui->request->env->{SSL_CLIENT_S_DN_CN} || $self->webui->request->env->{SSL_CLIENT_S_DN};
    my $cert = $self->webui->request->env->{SSL_CLIENT_CERT} || '';

    $self->log->trace('ENV is ' . Dumper \%ENV) if $self->log->is_trace;

    # Send login data
    if ($cert) {
        $self->log->info('Sending X509 Login ( '.$user.' )');
        my @chain;
        # larger chains are very unlikely and we dont support stupid clients
        for (my $cc=0;$cc<=3;$cc++)   {
            my $chaincert = $self->webui->request->env->{'SSL_CLIENT_CERT_CHAIN_'.$cc};
            last unless ($chaincert);
            push @chain, $chaincert;
        }

        my $data = { certificate => $cert, chain => \@chain };
        $data = $self->_jwt_signature($data, $jws) if ($jws);

        $self->_send_to_backend( 'GET_X509_LOGIN', $data);
        $self->log->trace('Auth result ' . Dumper $self->last_reply) if $self->log->is_trace;
        return $self->_check_response;
    }

    # Error: no cert
    $self->log->error('Certificate missing for X509 Login');
    $self->webui->logout_session;
    return $self->page_obj->init_login_missing_data;
}

sub _handle_GET_OIDC_LOGIN ($self, $page, $auth, $realm, $auth_stack) {
    my %oidc_client = map {
        ($_ => ($auth->{$_} || die "OIDC setup incomplete, '$_' is not set"));
    } qw(client_id auth_uri token_uri client_secret);

    $self->log->trace(SDumper \%oidc_client) if ($self->log->is_trace);

    # Send login data.
    # We use "page" to transport the token.
    if ($page =~ m{login!oidc!token!([\w\-\.]+)\z}) {
        # Step 3 - use token to perform authentication
        my $token = $1;
        $self->log->debug('OIDC Login (3/3) - present token to backend');
        $self->log->trace("Token = $token");
        my $nonce = $self->webui->session->param('oidc-nonce')
            or return $self->page_obj->init_login_missing_data;

        $self->webui->session->param('oidc-nonce' => undef);
        $self->_send_to_backend( 'GET_OIDC_LOGIN', {
            token => $token,
            client_id => $oidc_client{client_id},
            nonce => $nonce,
        });
        return $self->_check_response;

    }

    my $tt = OpenXPKI::Template->new;
    my $uri_pattern = $auth->{redirect_uri} || 'https://[% host _ baseurl %]';
    my $redirect_uri = $tt->render( $uri_pattern, {
        host => $self->webui->normalized_request_url->host,
        baseurl => $self->webui->base_url,
        realm => $realm,
        stack => $auth_stack,
    });

    if (my $code = $self->webui->param('code')) {

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

        # Error
        if (not $response->is_success) {
            $self->log->warn("Unable to redeem token, error was: " . $response->decoded_content);
            $self->page_obj->status->error('Unable to redeem token');
            $self->page_obj->redirect->to('login!missing_data');
            return $self->page_obj;
        }

        my $auth_info = $self->webui->json->decode($response->decoded_content);

        # store token in session and redirect
        $self->log->debug('OIDC Login (2/3) - store token and redirect');
        $self->log->trace('Token: ' . Dumper $auth_info) if $self->log->is_trace;

        $self->page_obj->redirect->to('login!oidc!token!'.$auth_info->{id_token});
        return $self->page_obj;

    } elsif ($self->webui->session->param('oidc-nonce')) {

        # to avoid an endless loop in case the user is not willing
        # or able to complete the OIDC login, we use the nonce
        # in the session to detect a "returning user" and render an
        # info page instead of doing a redirect
        $self->webui->logout_session;
        return $self->page_obj->init_login_missing_data;

    } else {

        # Initial step - assemble auth token request and send redirect
        my $nonce = Data::UUID->new->create_b64;
        my $sess_id = $self->webui->has_cipher ?
            encode_base64($self->webui->cipher->encrypt($self->webui->session->id),'') :
            $self->webui->session->id;

        # TODO - this is only set if we had a roundtrip before
        # move this into the session
        my $hash_key = $self->webui->request->cookie('oxi-extid');
        die "No external key to prepare OIDC" unless($hash_key);
        my $auth_token = {
            response_type => 'code',
            client_id => $oidc_client{client_id},
            scope => ($auth->{scope} || 'openid profile email'),
            redirect_uri => $redirect_uri.'/oidc_redirect',
            state => encode_jwt( alg => 'HS256', key => $hash_key->value, payload => {
                session_id => $sess_id,
                baseurl => $redirect_uri,
            }),
            nonce => $nonce,
        };
        $self->log->debug('OIDC Login (1/3) - redirect to ' . $oidc_client{auth_uri});
        $self->webui->session->param('oidc-nonce',$nonce);

        my $loginurl = $oidc_client{auth_uri}.'?'.join('&', (map { $_ .'='. uri_escape($auth_token->{$_})  } keys %{$auth_token}));
        $self->page_obj->redirect->external($loginurl);
        return $self->page_obj;
    }
}

sub _handle_GET_PASSWD_LOGIN ($self, $action, $auth, $jws) {
    # form send / credentials are passed (works with an empty form too...)

    # Send login data
    if ($action eq 'login!password') {
        $self->log->debug('PASSWD auth try - validating username/password');
        ##FIXME - Input validation

        my $data;
        my @fields = $auth->{field}
            ? (map { $_->{name} } $auth->{field}->@*)
            : ('username', 'password');

        foreach my $field (@fields) {
            my $val = $self->webui->param($field);
            next unless $val;
            $data->{$field} = $val;
        }

        $data = $self->_jwt_signature($data, $jws) if $jws;

        $self->_send_to_backend( 'GET_PASSWD_LOGIN', $data );
        $self->log->trace('Auth result = ' . Dumper $self->last_reply) if $self->log->is_trace;
        return $self->_check_response;
    }

    # Render form
    $self->log->debug('No credentials, render form');
    return $self->page_obj->init_login_passwd($auth);
}

sub _check_response ($self) {
    if ('SERVICE_READY' eq $self->last_reply->{SERVICE_MSG}) {

        $self->log->info('Authentication successful - fetch session info');
        # Fetch the user info from the server
        $self->_send_to_backend( 'COMMAND',
            { COMMAND => 'get_session_info', PARAMS => {}, API => 2 } );

        if ( $self->last_reply->{SERVICE_MSG} eq 'COMMAND' ) {

            my $session_info = $self->last_reply->{PARAMS};

            # merge base URL to authinfo links
            # (we need to get the baseurl before recreating the session below)
            my $auth_info = {};
            if (my $ai = $session_info->{authinfo}) {
                my $tt = OpenXPKI::Template->new;
                for my $key (keys $ai->%*) {
                    $auth_info->{$key} = $tt->render(
                        $ai->{$key}, { baseurl => $self->webui->base_url }
                    );
                }
            }
            delete $session_info->{authinfo};

            #$self->webui->client->rekey_session;
            #my $new_backend_session_id = $self->webui->client->get_session_id;

            # Generate a new frontend session to prevent session fixation
            # The backend session remains the same but can not be used by an
            # adversary as the id is never exposed and we destroy the old frontend
            # session so access to the old session is not possible
            $self->_recreate_frontend_session($session_info, $auth_info);

            if (my $login_page = $auth_info->{login}) {
                $self->page_obj->redirect->to($login_page);
            } else {
                $self->page_obj->init_index;
            }
            return $self->page_obj;
        }
    }

    if ('ERROR' eq $self->last_reply->{SERVICE_MSG}) {
        $self->log->trace('Server error: '. Dumper $self->last_reply) if $self->log->is_trace;

        # Failure here is likely a wrong password
        my $msg = $self->last_reply->{'ERROR'} && ($self->last_reply->{'ERROR'}->{CLASS}//'') eq 'OpenXPKI::Exception::Authentication'
            ? $self->last_reply->{'ERROR'}->{LABEL}
            : $self->page_obj->message_from_error_reply($self->last_reply);

        $self->page_obj->status->error($msg);
        return $self->page_obj;
    }

    $self->log->error("Unhandled error during auth");
    $self->page_obj->status->error("Unhandled error during authentication");
    return $self->page_obj;
}

=head2 is_logout

Checks if the given page string is logout related.

=cut
sub is_logout ($self, $page) {
    return ($page eq 'logout' or $page eq 'login!logout') ? 1 : 0;
}

=head2 logout

Handle a logout or post-logout display request. Destroys the current frontend
and backend sessions, honours any SSO logout redirect configured in the session,
and renders the "you have been logged out" confirmation page.

B<Parameters>

=over

=item * C<$page> I<Str> - required: the current page string. Only C<"logout"> and
C<"login!logout"> are acted upon; all other values cause an immediate C<undef>
return.

=back

=cut
sub logout ($self, $page) {
    die "logout() called with invalid page string '$page'" unless $self->is_logout($page);

    $self->clear_page_obj; # paranoia: guard against multiple calls to logout() within one request

    if ($page eq 'logout') {
        # For SSO Logins the session might hold an external link
        # to logout from the SSO provider
        my $authinfo = $self->webui->session->param('authinfo') || {};
        my $goto = $authinfo->{logout};

        # create new frontend and backend sessions
        $self->webui->logout_session; # this will preserve "pki_realm" and "auth_stack" (if fixed)

        # make sure backend session knows realm and frontend session knows
        # backend session so e.g. "get_menu" returns the proper logout menu from
        # the realm config (if any).
        $self->webui->_init_client($self->webui->client); # initialize backend session and store its ID in frontend session

        if (my $realm = $self->webui->session->param('pki_realm')) {
            my $auth_stack = $self->webui->session->param('is_fixed_auth_stack') # auth_stack shouldn't be there after session renewal if it's not fixed, but we check anyways
                ? $self->webui->session->param('auth_stack')
                : undef;
            # store realm in backend session
            my $reply = $self->webui->ping_client;
            if ($reply->{SERVICE_MSG} eq 'GET_PKI_REALM') {
                $self->webui->client->send_receive_service_msg('GET_PKI_REALM', {
                    PKI_REALM => $realm,
                    $auth_stack ? (AUTHENTICATION_STACK => $auth_stack) : (),
                });
            }
        }

        # perform the redirect if set
        if ($goto) {
            $self->log->debug("External redirect on logout to: $goto");
            $self->page_obj->redirect->external($goto);
        } else {
            $self->page_obj->redirect->to('login!logout');
        }

        return $self->page_obj;
    }

    # show the "you have been logged out" page
    if ($page eq 'login!logout') {
        return $self->page_obj->init_logout;
    }
}

sub _send_to_backend ($self, @args) {
    my $reply = $self->webui->client->send_receive_service_msg(@args);
    $self->last_reply($reply);
    return $reply;
}

sub _jwt_signature ($self, $data, $jws) {
    return unless defined $self->jwt_key;

    $self->log->debug('Sign data using key id ' . $jws->{keyid} );
    my $pkey = $self->jwt_key;

    return encode_jwt(
        payload => {
            param => $data,
            sid => $self->webui->client->get_session_id,
        },
        key => \$pkey,
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
        my $val = $self->webui->session->param($_);
        (defined $val) ? ($_ => $val) : ();
    } ('redirect','baseurl');

    $self->log->trace("Carry over session items: " . Dumper \%keep) if ($self->log->is_trace);

    # create a new session
    $self->webui->new_frontend_session;

    map { $self->webui->session->param($_, $keep{$_}) } keys %keep;

    # set some data
    $self->webui->session->param('backend_session_id', $self->webui->client->get_session_id );

    # move userinfo to own node
    $self->webui->session->param('userinfo', $session_info->{userinfo} || {});
    delete $session_info->{userinfo};

    $self->webui->session->param('authinfo', $auth_info);

    $self->webui->session->param('user', $session_info);
    $self->webui->session->param('pki_realm', $session_info->{pki_realm});
    $self->webui->session->param('is_logged_in', 1);
    $self->webui->session->param('initialized', 1);
    $self->webui->session->param('login_timestamp', time);

    # Check for MOTD, e.g. { level => 'warn', message => 'Beware!' }
    my $motd = $self->webui->client->send_receive_command_msg( 'get_motd' );
    if (ref $motd->{PARAMS} eq 'HASH') {
        $self->log->trace('Got MOTD: '. Dumper $motd->{PARAMS} ) if $self->log->is_trace;
        $self->webui->session->param('motd', $motd->{PARAMS} );
    }

    # Set menu
    $self->_set_menu;
}

sub _set_menu ($self) {
    my $reply = $self->webui->client->send_receive_command_msg('get_menu');
    my $menu = $reply->{PARAMS} or return;

    $self->log->trace('UI config = ' . Dumper $menu) if $self->log->is_trace;

    $self->webui->session->param('menu_items', $menu->{main} || []);

    # persist the optional parts of the menu hash (landmark, tasklist, search attribs)
    $self->webui->session->param('landmark', $menu->{landmark} || {});
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
        $self->webui->session->param('ping', $ping);
    }

    # tasklist, wfsearch, certsearch and bulk can have multiple branches
    # using named keys. We try to autodetect legacy formats and map
    # those to a "default" key
    # TODO Remove legacy compatibility

    # config items are a list of hashes
    foreach my $key (qw(tasklist bulk)) {

        if (ref $menu->{$key} eq 'ARRAY') {
            $self->webui->session->param($key, { 'default' => $menu->{$key} });
        } elsif (ref $menu->{$key} eq 'HASH') {
            $self->webui->session->param($key, $menu->{$key} );
        } else {
            $self->webui->session->param($key, { 'default' => [] });
        }
        $self->log->trace("Got $key: " . Dumper $menu->{$key}) if $self->log->is_trace;
    }

    # top level is a hash that must have a "attributes" node
    # legacy format was a single list of attributes
    # TODO Remove legacy compatibility
    foreach my $key (qw(wfsearch certsearch)) {

        # plain attributes
        if (ref $menu->{$key} eq 'ARRAY') {
            $self->webui->session->param($key, { 'default' => { attributes => $menu->{$key} } } );
        } elsif (ref $menu->{$key} eq 'HASH') {
            $self->webui->session->param($key, $menu->{$key} );
        } else {
            # empty hash is used to disable the search page
            $self->webui->session->param($key, {} );
        }
        $self->log->trace("Got $key: " . Dumper $menu->{$key}) if $self->log->is_trace;
    }

    foreach my $key (qw(datapool)) {
        if (ref $menu->{$key} eq 'HASH' and $menu->{$key}->{default}) {
            $self->webui->session->param($key, $menu->{$key} );
        } else {
            $self->webui->session->param($key, { default => {} });
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
    $self->webui->session->param('certdetails', $certdetails);

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
    $self->webui->session->param('wfdetails', $wfdetails);
}

__PACKAGE__->meta->make_immutable;
