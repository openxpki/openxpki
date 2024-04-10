package OpenXPKI::Client::Web::Controller;
use OpenXPKI -base => 'Mojolicious::Controller';

# Core modules
use Module::Load;

# Project modules
use OpenXPKI::Log4perl;
use OpenXPKI::Client::Service::Response;


sub index ($self) {
    # read target service class
    my $class = $self->stash('service_class') or die "Missing 'service_class' in Mojolicious stash";

    # load and instantiate service class
    my $service;
    try {
        Module::Load::load $class;
        $service = $class->new(
            config_obj => $self->oxi_config($class->service_name),
            apache_env => $self->stash('apache_env'),
            remote_address => $self->tx->remote_address,
            request => $self->req,
            endpoint => $self->stash('endpoint'),
        );
        die "Service class $class does not consume role OpenXPKI::Client::Service::Role::Base"
          unless $service->DOES('OpenXPKI::Client::Service::Role::Base');
    }
    catch ($error) {
        die sprintf("Error loading service class '%s': %s", $class, $error);
    }

    # replace Mojolicious logger by our own
    $self->app->log(OpenXPKI::Log4perl->get_logger('client.' . $service->service_name));
    $self->stash('mojo.log' => undef); # reset DefaultHelper "log" (i.e. $self->log) which accesses stash "mojo.log"

    $self->log->debug("Service class $class instantiated");

    # preparations and checks
    $self->log->debug("Request handling (1/3): preparations and checks");
    $service->prepare($self);

    # request handling
    $self->log->debug("Request handling (2/3): process request");
    my $response = $service->handle_request;
    die "Result of $class->handle_request() is not an instance of OpenXPKI::Client::Service::Response"
      unless $response->isa('OpenXPKI::Client::Service::Response');

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
