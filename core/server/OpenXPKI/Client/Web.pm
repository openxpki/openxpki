package OpenXPKI::Client::Web;
use OpenXPKI -base => 'Mojolicious';

# Core modules
use re qw( regexp_pattern );
use Module::Load ();
use POSIX ();
use List::Util qw( first );

# CPAN modules
use Mojo::Util qw( url_unescape encode tablify );

# Project modules
use OpenXPKI::Client::Config;
use OpenXPKI::Util;

my $socketfile = $ENV{OPENXPKI_CLIENT_SOCKETFILE} || '/var/openxpki/openxpki.socket';

=head1 NAME

OpenXPKI::Client::Web - Mojolicious application: entry point for HTTP request handling

=head1 DESCRIPTION

Service (aka. "client protocol") requests are handled by Mojolicious based
request processing. This deprecates the old FCGI scripts.

Services are enabled via client configuration and their Perl classes are then
autodiscovered in L<OpenXPKI::Client::Web>.

=cut
# TODO Document client service configuration once specified
=pod

We use a common Mojolicious controller L<OpenXPKI::Client::Web::Controller>
for all services and requests to avoid code duplication and enforce some
processing standards.

Each service must provide a class that consumes the
L<OpenXPKI::Client::Service::Role::Info> role. Method
C<L<declare_routes()|OpenXPKI::Client::Service::Role::Info/declare_routes>>
required by this role is responsible for the registration of the Mojolicious
URL routes for the service. Every route is expected to contain the
I<service_class> stash parameter. This parameter is used by the controller to
instantiate the service specific request processing class which must consume
L<OpenXPKI::Client::Service::Role::Base>. Usually both roles are consumed by
the same class.

Overview of the relevant packages:

=over

=item C<OpenXPKI::Client::Web>

Service discovery and setup (Mojolicious application), see L</startup>.

=item C<L<OpenXPKI::Client::Web::Controller>>

Request handling and pre-/post-processing (common Mojolicious controller used by all services).

=item C<L<OpenXPKI::Client::Service::Role::Info>>

Service route info role.

=item C<L<OpenXPKI::Client::Service::Role::Base>>

Service request processing role.

=back

=cut

###############################################################################

=head1 METHODS

=head2 startup

Called by Mojolicious it does the following:

=over

=item Load service classes

Try and load the service I<info> classes for all configured services under the
package namespace C<OpenXPKI::Client::Service::*>.

For a configured service named C<"est"> the following class lookups are done:

    OpenXPKI::Client::Service::EST
    OpenXPKI::Client::Service::Est
    OpenXPKI::Client::Service::est

A service I<info> class must consume L<OpenXPKI::Client::Service::Role::Info>.

=item Register routes

Call all service info classes' static
C<L<declare_routes()|OpenXPKI::Client::Service::Role::Info/declare_routes>>
methods which register all routes of the given service below
C<https://E<lt>hostE<gt>/E<lt>service_nameE<gt>/>. For every route two special
OpenXPKI Mojolicious stash values I<service_class> and I<endpoint> are expected
to be set.

The target L<OpenXPKI::Client::Web::Controller/index> and the Mojolicious stash
parameter C<service_name> are automatically set for every route.

=item Inject ENV

Register a Mojolicious C<before_dispatch> hook that will inject ENV variables
sent via C<X-OpenXPKI-Apache-ENV-*> HTTP headers.

=item Helper C<oxi_config>

Register the Mojolicious helper C<oxi_config> which returns an instance of
L<OpenXPKI::Client::Config>. Used in L<OpenXPKI::Client::Web::Controller>.

=back

=cut
sub startup ($self) {
    #my $config = $self->{oxi_config_obj} or die 'Missing parameter "oxi_config_obj" to ' . __PACKAGE__ . '->new()';
    my $user = $self->{oxi_user};
    my $group = $self->{oxi_group};
    my $socket_user = $self->{oxi_socket_user};
    my $socket_group = $self->{oxi_socket_group};

    # we use the stash to store the flag because $self in helper_oxi_config()
    # refers to an OpenXPKI::Client::Web::Controller instance
    $self->defaults('skip_log_init' => 1) if $self->{oxi_skip_log_init};

    #$self->secrets(['Mojolicious rocks']);

    $self->exception_format('txt') unless 'development' eq $self->mode;

    # Helpers
    $self->helper(oxi_config => $self->can('helper_oxi_config'));

    #
    # Routes
    #

    # some common stash values / config
    $self->routes->to(
        namespace => '',
        controller => 'OpenXPKI::Client::Web::Controller',
        action => 'index',
    );

    # my $services = $self->oxi_config->list_services;
    my $services = [ qw( healthcheck est rpc scep webui ) ];

    for my $service ($services->@*) {
        # fetch the class that consumes OpenXPKI::Client::Service::Role::Info
        my $class = $self->_load_service_class($service) or next;
        # inject "service_name" into stash, but only for this route
        my $child_route = $self->routes->under(sub ($c) { $c->stash(service_name => $service) });
        # ->can() is the best way to invoke a method on a dynamic class
        my $declare_routes = $class->can('declare_routes');
        # call declare_routes()
        $declare_routes->($child_route);
    }

    if ($self->log->is_debug) {
        my $rows = [];
        _walk_route($_, 0, $rows) for $self->routes->children->@*;
        $self->log->debug('Routes:');
        $self->log->debug($_) for map { "  $_" } split "\n", tablify($rows);
    }

    #
    # Logging on server start / shutdown
    #
    $self->hook(before_server_start => sub ($server, $app) { # Mojolicious server start hook
        $self->log->debug(sprintf 'Start OpenXPKI HTTP server in "%s" mode (pid %s)', $self->mode, $$);

        my $on_finish = sub {
            $self->log->debug("Stop OpenXPKI HTTP server (pid $$)");
        };

        if ($server->isa('Mojo::Server::Prefork')) {
            $server->on(finish => $on_finish);
            # Drop privileges (manager process)
            # (the "wait" event happends after PID file creation)
            $server->once(wait => sub ($server) {
                my $socket_file = $server->ioloop->acceptor($server->acceptors->[0])->handle->hostpath;
                $self->_chown_socket($socket_file, $socket_user, $socket_group);
                $self->_drop_privileges($server->pid_file, $user, $group, "Manager $$");
            });
        } else {
            $self->log->warn('The OpenXPKI client will only work properly with Mojolicious server Mojo::Server::Prefork');
        }
        # } elsif ($server->isa('Mojo::Server::Daemon')) {
        #     # The following does currently not work
        #     # (it was proposed by a Mojolicious developer in 2018:
        #     # https://github.com/mojolicious/mojo/issues/1255#issuecomment-417866464)
        #     $server->ioloop->on(finish => $on_finish);
        # }

        # Drop privileges (worker processes)
        Mojo::IOLoop->next_tick(sub { $self->_drop_privileges($server->pid_file, $user, $group, "Worker $$") });
    });

    #
    # Inject query string and Apache ENV from our custom HTTP headers
    #
    $self->hook(before_dispatch => sub ($c) { # Mojolicious request dispatch hook
        $self->log->trace(sprintf 'Incoming %s request', uc($c->req->url->base->protocol)); # ->protocol: Normalized version of ->scheme

        if ($self->mode eq 'development') {
            $self->log->warn('Enforce HTTPS because of Mojolicious development mode');
            $c->req->url->base->scheme('https');
        }

        # unescape header values (for some reason they are url escaped)
        for my $key ($c->req->headers->names->@*) {
            my @val = map { url_unescape($_) } $c->req->headers->every_header($key)->@*;
            $c->req->headers->header($key, @val);
        }

        # Inject forwarded Apache ENV into Mojo::Request
        $self->log->error("Missing header X-OpenXPKI-Apache-ENVSET - Apache setup seems to be incomplete")
            unless $c->req->headers->header('X-OpenXPKI-Apache-ENVSET');

        my $headers = $c->req->headers->to_hash;
        my $apache_env = {};
        for my $header (sort keys $headers->%*) {
            if (my ($env_key) = $header =~ /^X-OpenXPKI-Apache-ENV-(.*)/) {
                my $val = $headers->{$header};
                $apache_env->{$env_key} = $val;
                $self->log->trace("Apache ENV variable received via header: $env_key");
            }
        }
        $c->stash(apache_env => $apache_env);

        # Inject query parameters forwarded by Apache into Mojo::Request.
        # NOTE:
        # We need this workaround because Apache cannot forward the
        # QUERY_STRING to the backend server. The "proxy_pass" documentation
        # which is also valid for "RewriteRule ... url [p]" says: "url is a
        # partial URL for the remote server and cannot include a query string."
        # (https://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass)
        if (my $query = $c->req->headers->header('X-OpenXPKI-Apache-QueryString')) {
            $c->req->url->query($query);
            $self->log->trace("Apache QUERY_STRING received via header: $query");
        }
    });
}

# We implement the config helper to be able to cache configurations across
# multiple requests.
sub helper_oxi_config ($self, $service, $no_config) {
    state $configs = {}; # cache config object accross requests

    die "No service specified in call to helper 'oxi_config'" unless $service;

    unless ($configs->{$service}) {
        $self->log->debug("Load configuration for service '$service'");
        $configs->{$service} = OpenXPKI::Client::Config->new(
            service => $service,
            $no_config ? ( default => {} ) : (),
            $self->stash('skip_log_init') ? (skip_log_init => 1) : (),
        );
    }

    return $configs->{$service};
}

sub _chown_socket ($self, $socket_file, $user, $group) {
    #
    # Modify socket ownership and permissions
    #
    my (undef, $s_uid, undef, $s_gid) = OpenXPKI::Util->resolve_user_group(
        $user, $group, 'socket', 1
    );
    #my $socket_file = $daemon->ioloop->acceptor($daemon->acceptors->[0])->handle->hostpath;
    chmod 0660, $socket_file;
    my @changes = ();
    if (defined $s_uid) {
        chown $s_uid, -1, $socket_file;
        push @changes, "user = $user";
    }
    if (defined $s_gid) {
        chown -1, $s_gid, $socket_file;
        push @changes, "group = $group";
    }
    $self->log->info('Socket ownership set to: ' . join(', ', @changes)) if @changes;
}

sub _drop_privileges ($self, $pid_file, $user, $group, $label) {
    my (undef, $uid, undef, $gid) = OpenXPKI::Util->resolve_user_group($user, $group, 'Mojolicious daemon', 1);

    # ownership already correct - nothing to do
    return if (POSIX::getuid == ($uid//-1) and POSIX::getgid == ($gid//-1));

    # change file ownership before dropping privileges!
    chown $uid, -1, $pid_file if defined $uid;
    chown -1, $gid, $pid_file if defined $gid;

    # drop privileges
    my @changes = ();
    if (defined $uid) {
        $ENV{USER} = getpwuid($uid);
        $ENV{HOME} = ((getpwuid($uid))[7]);
        POSIX::setuid($uid);
        push @changes, "user = $user";
    }
    if (defined $gid) {
        POSIX::setgid($gid);
        push @changes, "group = $group";
    }
    $self->log->info("$label dropped privileges, new process ownership: " . join(', ', @changes)) if @changes;
}

sub _load_service_class ($self, $service_short) {
    my $prefix = 'OpenXPKI::Client::Service::';
    my $service = $prefix.$service_short;

    my $service_modules = OpenXPKI::Util->list_modules($prefix);
    my $pkg = first { lc($service) eq lc($_) } keys $service_modules->%*;

    if ($pkg) {
        try {
            require $service_modules->{$pkg};
        }
        catch ($err) {
            die sprintf 'Could not load class for service "%s": %s', $service_short, $err;
        }

        die sprintf 'Class "%s" must consume role OpenXPKI::Client::Service::Role::Info', $pkg
            unless $pkg->DOES('OpenXPKI::Client::Service::Role::Info');

        $self->log->debug(sprintf 'Service "%s": enabled (%s)', $service_short, $pkg);
        return $pkg;

    } else {
        $self->log->warn(sprintf 'Service "%s": skipped - no matching class found', $service_short);
        return;
    }
}

# from Mojolicious::Command::routes
sub _walk_route ($route, $depth, $rows) {
    # Pattern
    my $prefix = '';
    if (my $i = $depth * 2) { $prefix .= ' ' x $i . '+' }
    push @$rows, my $row = [$prefix . ($route->pattern->unparsed || '/')];

    # Methods
    my $methods = $route->methods;
    push @$row, (!$methods ? '*' : uc join ',', @$methods) . ($route->is_websocket ? ' (WS)' : '');

    # Regex
    my $pattern = $route->pattern;
    $pattern->match('/', $route->is_endpoint && !$route->partial);
    push @$row, (regexp_pattern $pattern->regex)[0];

    _walk_route($_, $depth+1, $rows) for $route->children->@*;
}

1;
