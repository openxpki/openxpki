package OpenXPKI::Client::Web;
use OpenXPKI -base => 'Mojolicious';

# Core modules
use re qw( regexp_pattern );
use Module::Load ();

# CPAN modules
use Mojo::Util qw( url_unescape encode tablify );

# Project modules
use OpenXPKI::Client::Config;
use OpenXPKI::Log4perl;


my $socketfile = $ENV{OPENXPKI_CLIENT_SOCKETFILE} || '/var/openxpki/openxpki.socket';


sub startup ($self) {

    $self->log(OpenXPKI::Log4perl->get_logger(''));

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
    my $services = [ qw( healthcheck est rpc scep acme ) ];

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
        $self->_walk_route($_, 0, $rows) for $self->routes->children->@*;
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
        }

        elsif ($server->isa('Mojo::Server::Daemon')) {
            # this does currently not work
            # (it was proposed by a Mojolicious developer in 2018:
            # https://github.com/mojolicious/mojo/issues/1255#issuecomment-417866464)
            $server->ioloop->on(finish => $on_finish);
        }
    });

    #
    # Inject query string and Apache ENV from our custom HTTP headers
    #
    $self->hook(before_dispatch => sub ($c) { # Mojolicious request dispatch hook
        $self->log->trace(sprintf 'Incoming %s request', uc($c->req->url->base->protocol)); # ->protocol: Normalized version of ->scheme

        if ($self->mode eq 'development') {
            $self->log->trace('Development mode: enforce HTTPS');
            $c->req->url->base->scheme('https');
        }

        # Inject forwarded Apache ENV into Mojo::Request
        $self->log->error("Missing header X-OpenXPKI-Apache-ENVSET - Apache setup seems to be incomplete")
            unless $c->req->headers->header('X-OpenXPKI-Apache-ENVSET');

        my $headers = $c->req->headers->to_hash;
        my $apache_env = {};
        for my $header (sort keys $headers->%*) {
            if (my ($key) = $header =~ /^X-OpenXPKI-Apache-ENV-(.*)/) {
                my $val = url_unescape($headers->{$header});
                $apache_env->{$key} = $val;
                $self->log->trace("Apache ENV variable received via header: $key");
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
        if (my $query_escaped = $c->req->headers->header('X-OpenXPKI-Apache-QueryString')) {
            my $query = url_unescape($query_escaped);
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
        );
    }

    return $configs->{$service};
}

sub _load_service_class ($self, $service) {
    my @variants = (
        sprintf("OpenXPKI::Client::Service::%s", uc $service),
        sprintf("OpenXPKI::Client::Service::%s", ucfirst $service),
        sprintf("OpenXPKI::Client::Service::%s", $service),
    );

    for my $pkg (@variants) {
        try {
            Module::Load::load($pkg);
        }
        catch ($err) {
            next if $err =~ /^Can't locate/;
            die sprintf 'Could not load class for service "%s": %s', $service, $err;
        }

        die sprintf 'Class "%s" must consume role OpenXPKI::Client::Service::Role::Info', $pkg
            unless $pkg->DOES('OpenXPKI::Client::Service::Role::Info');

        $self->log->debug(sprintf 'Service "%s": enabled (%s)', $service, $pkg);
        return $pkg;
    }

    $self->log->warn(sprintf 'Service "%s": skipped - no matching class found', $service);
    return;
}

# from Mojolicious::Command::routes
sub _walk_route ($self, $route, $depth, $rows) {
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

    _walk($_, $depth+1, $rows) for $route->children->@*;
}

1;
