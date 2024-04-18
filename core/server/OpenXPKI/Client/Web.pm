package OpenXPKI::Client::Web;
use OpenXPKI -base => 'Mojolicious';

# CPAN modules
use Mojo::Util qw( url_unescape );

# Project modules
use OpenXPKI::Client;
use OpenXPKI::Client::Config;
use OpenXPKI::Log4perl;


my $socketfile = $ENV{OPENXPKI_CLIENT_SOCKETFILE} || '/var/openxpki/openxpki.socket';

sub declare_routes ($self, $r) {
    # Health Check
    $r->get('/healthcheck' => sub { shift->redirect_to('check', command => 'ping') });
    $r->get('/healthcheck/<command>')->to('Healthcheck#index')->name('check');

    # Reserved Mojolicious keywords to load our shared controller
    my %controller_params = (
        namespace => '',
        controller => 'OpenXPKI::Client::Web::Controller',
        action => 'index',
    );

    # EST urls look like
    #   /.well-known/est/cacerts
    #   /.well-known/est/namedservice/cacerts  # incl. endpoint
    # <endpoint> is optional because a default is given.
    $r->any('/.well-known/est/<endpoint>/<operation>')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::EST',
        endpoint => 'default',
    );

    # SCEP urls look like
    #   /scep/server?operation=PKIOperation                 # incl. endpoint/server
    #   /scep/server/pkiclient.exe?operation=PKIOperation   # incl. endpoint/server
    # <*throwaway> is a catchall placeholder which is optional (because a default is given).
    $r->any('/scep/<endpoint>/<*throwaway>')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::SCEP',
        throwaway => '',
    );

    # ACME urls look like (full pattern)
    # /acme/<endpoint>/<objectclass>/<resource id>/<sub method>
    # but we need to handle some special path directly

    # /acme/<endpoint> - directory request
    $r->get('/acme/<endpoint>')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME',
        operation => 'directory'
    );

    # /acme/<endpoint>/newNonce - nonce request
    $r->any(['GET', 'HEAD'] => '/acme/<endpoint>/newNonce')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME',
        operation => 'nonce'
    );

    $r->post('/acme/<endpoint>/order/<resource_id>/finalize')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME::Order',
        operation => 'finalize',
    );

    $r->post('/acme/<endpoint>/revokeCert')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME::Cert',
        operation => 'revokeCert',
    );

    # not yet implemented in backend
    $r->post('/acme/<endpoint>/keyChange')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME::Account',
        operation => 'keyChange',
    );

    $r->post('/acme/<endpoint>/chall-http/<resource_id>')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME::Authz',
        operation => 'validate_http',
    );

    $r->post('/acme/<endpoint>/'.$_.'/<resource_id>')->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME::'.ucfirst($_),
        operation => $_
    ) for qw(order orders account authz cert);

    $r->post('/acme/<endpoint>/'.$_)->to(
        %controller_params,
        service_class => 'OpenXPKI::Client::Service::ACME::'.ucfirst(substr($_,3)),
        operation => $_,
    ) for qw(newAccount newAuthz newOrder);

}

sub startup ($self) {

    $self->log(OpenXPKI::Log4perl->get_logger(''));

    #$self->secrets(['Mojolicious rocks']);

    $self->exception_format('txt') unless 'development' eq $self->mode;

    # Routes
    my $r = $self->routes;
    $r->namespaces(['OpenXPKI::Client::Web']); # Mojolicious defaults is OpenXPKI::Client::Web::Controller::*
    $self->declare_routes($r);

    # Helpers
    $self->helper(oxi_config => $self->can('helper_oxi_config'));
    $self->helper(oxi_client => $self->can('helper_oxi_client'));

    # Mojolicious server start hook
    $self->hook(before_server_start => sub ($server, $app) {
        $self->log->debug(sprintf "Start OpenXPKI HTTP server in '%s' mode: pid = %s", $self->mode, $$);

        my $close_connection = sub {
            $self->log->debug("Stop OpenXPKI HTTP server: pid = $$");
            $app->oxi_client->close_connection if $app->oxi_client(skip_creation => 1);
        };

        if ($server->isa('Mojo::Server::Prefork')) {
            $server->on(finish => $close_connection);
        }

        elsif ($server->isa('Mojo::Server::Daemon')) {
            # this does currently not work
            # (it was proposed by a Mojolicious developer in 2018:
            # https://github.com/mojolicious/mojo/issues/1255#issuecomment-417866464)
            $server->ioloop->on(finish => $close_connection);
        }
    });


    # Change scheme if "X-Forwarded-HTTPS" header is set
    $self->hook(before_dispatch => sub ($c) {
        $self->log->trace(sprintf 'Incoming %s request', uc($c->req->url->base->protocol)); # ->protocol: Normalized version of ->scheme

        $self->log->error("Missing header X-OpenXPKI-Apache-ENVSET - Apache setup seems to be incomplete")
            unless $c->req->headers->header('X-OpenXPKI-Apache-ENVSET');

        # Inject forwarded Apache ENV into Mojo::Request
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

        # Inject forwarded query parameters into Mojo::Request.
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

        if ($self->mode eq 'development') {
            $self->log->trace('Development mode: enforcing HTTPS');
            $c->req->url->base->scheme('https');
        }
    });
}

# We implement the config helper to be able to cache configurations across
# multiple requests.
sub helper_oxi_config ($self, $service) {
    state $configs = {}; # cache config object accross requests

    die "No service specified in call to helper 'oxi_config'" unless $service;

    unless ($configs->{$service}) {
        $self->log->debug("Load configuration for service '$service'");
        $configs->{$service} = OpenXPKI::Client::Config->new($service);
    }

    return $configs->{$service};
}

signature_for helper_oxi_client => (
    method => 1,
    named => [
        skip_creation => 'Bool', { default => 0 },
    ],
);
sub helper_oxi_client ($self, $arg) {
    state $client; # cache client accross requests

    if ($client and not $client->is_connected) {
        $client = undef;
    }

    unless ($client or $arg->skip_creation) {
        try {
            $client = OpenXPKI::Client->new({
                SOCKETFILE => $socketfile,
            });
            $client->init_session;
            $self->log->debug("Got new client: " . $client->session_id);
        }
        catch ($err) {
            $client = undef;
            $self->log->error("Unable to bootstrap client: $err");
        }
    }

    return $client;
}

1;
