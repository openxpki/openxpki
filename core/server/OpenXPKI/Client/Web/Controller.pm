package OpenXPKI::Client::Web::Controller;
use OpenXPKI -base => 'Mojolicious::Controller';

# Core modules
use Module::Load ();

# Project modules
use OpenXPKI::Log4perl;


sub index ($self) {
    # read target service class
    my $class = $self->stash('service_class') or die "Missing parameter 'service_class' in Mojolicious stash";
    my $service_name = $self->stash('service_name') or die "Missing parameter 'service_class' in Mojolicious stash";
    my $no_config = $self->stash('no_config');
    my $endpoint = $self->stash('endpoint') or die "Missing parameter 'endpoint' in Mojolicious stash";

    # load and instantiate service class
    my $service;
    my $config;
    try {
        $config = $self->oxi_config($service_name, $no_config);

        Module::Load::load($class);
        $service = $class->new(
            service_name => $service_name,
            config_obj => $config,
            apache_env => $self->stash('apache_env'),
            remote_address => $self->tx->remote_address,
            request => $self->req,
            endpoint => $endpoint,
        );
        die "Service class $class does not consume role OpenXPKI::Client::Service::Role::Base"
          unless $service->DOES('OpenXPKI::Client::Service::Role::Base');
    }
    catch ($error) {
        die sprintf("Error loading service class '%s': %s", $class, $error);
    }

    # replace Mojolicious logger by our own
    $self->app->log($config->log);
    $self->stash('mojo.log' => undef); # reset DefaultHelper "log" (i.e. $self->log) which accesses stash "mojo.log"

    $self->log->debug("Service class $class instantiated");

    # preparations and checks
    $self->log->debug("Request handling (1/3): preparations and checks");

    my $response;
    try {
        $service->prepare($self);
        die "$class->operation must be set in $class->prepare()\n" unless $service->has_operation;
    }
    catch ($err) {
        $response = $service->new_error_response($err);
        $self->log->warn("Request handling (2/3) skipped due to error " . $response->error . ": " . $response->error_message);
    }

    if (not $response) {
        # request handling
        $self->log->debug("Request handling (2/3): process request");
        $response = $service->handle_request;
        die "Result of $class->handle_request() is not an instance of OpenXPKI::Client::Service::Response"
          unless $response->isa('OpenXPKI::Client::Service::Response');
    }

    # service specific HTTP headers
    $self->res->headers->add($_ => $response->extra_headers->{$_}) for keys $response->extra_headers->%*;

    # TODO -- needs to be overwritten in CertEP - it always returns 200
    $self->res->code($response->http_status_code);
    $self->res->message($response->http_status_message);

    # HTTP response
    $self->log->debug("Request handling (3/3): send response");
    $service->send_response($self, $response);
}

1;
