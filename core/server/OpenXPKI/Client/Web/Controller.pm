package OpenXPKI::Client::Web::Controller;
use OpenXPKI -base => 'Mojolicious::Controller';

# Core modules
use Module::Load ();
use List::Util 'any';
use Log::Log4perl;
use Log::Log4perl::MDC;

# Project modules
use OpenXPKI::Log4perl;
use OpenXPKI::i18n qw( set_language set_locale_prefix);

=head1 NAME

OpenXPKI::Client::Web::Controller - Common Mojolicious controller

=head1 DESCRIPTION

This is the central Mojolicious routing target (i.e. entrypoint) for requests
of all services. See L</index> for details.

=head1 METHODS

=head2 index

(Enforced by L<OpenXPKI::Client::Web/startup> as the routing target for all
HTTP service requests)

Service request processing:

=over

=item 1. Class instantiation

=over

=item * Read the I<service_class> stash value set by C<L<declare_routes()|OpenXPKI::Client::Service::Role::Info/declare_routes>>,

=item * load the named class which must consume L<OpenXPKI::Client::Service::Role::Base> and

=item * create a service instance object.

=back

=item 2. Checks

Call the service objects' C<L<prepare()|OpenXPKI::Client::Service::Role::Base/prepare>> method
for checks and general setup. The object attribute C<L<operation|OpenXPKI::Client::Service::Role::Base/operation>>
is expected to be set by C<prepare()>.

=item 3. Request processing

Call the roles' C<L<handle_request()|OpenXPKI::Client::Service::Role::Base/handle_request>>
method which itself queries the objects' C<L<op_handlers()|OpenXPKI::Client::Service::Role::Base/op_handlers>>
to fetch a request handler callback matching the C<operation> attribute.

Return value of C<handle_request()> is a L<OpenXPKI::Client::Service::Response> object.

=item 4. HTTP response

Turn the L<OpenXPKI::Client::Service::Response> object into a service specific
HTTP response by calling the objects' C<L<send_response()|OpenXPKI::Client::Service::Role::Base/send_response>>
method.

=back

=cut
sub index ($self) {
    # read target service class
    my $class = $self->stash('service_class') or die "Missing parameter 'service_class' in Mojolicious stash";
    my $service_name = $self->stash('service_name') or die "Missing parameter 'service_class' in Mojolicious stash";
    my $endpoint = $self->stash('endpoint') or die "Missing or empty parameter 'endpoint' in Mojolicious stash";
    my $no_config = $self->stash('no_config');

    # load and instantiate service class
    my $service;
    my $config;
    my %backend;
    try {
        $self->log->trace("Load configuration for '$service_name.$endpoint'");
        # FIXME - send 404 for unknown endpoints
        $config = $self->oxi_service_config($service_name, $endpoint)
            || die "No configuration found for this service";
        # for the WebUI we create a reusable backend instance via the factory
        # FIXME we need to rework the O:C:Simple to make it reusable too
        if (any { $service_name eq $_ } ('webui','healthcheck')) {
            %backend = ( client => $self->oxi_client() );
            $self->log->debug("Adding backend for $service_name in $$");
        }
    }
    catch ($error) {
        my $msg = sprintf("Error while loading configuration for service '%s': %s", $service_name, $error);
        $self->log->fatal($error);
        die "$error\n";
    }

    Log::Log4perl::MDC->put('endpoint', $endpoint);
    OpenXPKI::Log4perl->set_default_facility("openxpki.client.service.$service_name.$endpoint");

    # replace Mojolicious logger by our own
    $self->app->log(OpenXPKI::Log4perl->get_logger);
    $self->stash('mojo.log' => undef); # reset DefaultHelper "log" (i.e. $self->log) which accesses stash "mojo.log"

    try {
        $self->log->trace("Load service class $class");
        Module::Load::load($class);
        $service = $class->new(
            service_name => $service_name,
            config => $config,
            remote_address => $self->tx->remote_address,
            request => $self->req,
            endpoint => $endpoint,
            %backend
        );
        die "Service class $class does not consume role OpenXPKI::Client::Service::Role::Base"
          unless $service->DOES('OpenXPKI::Client::Service::Role::Base');
    }
    catch ($error) {
        die sprintf("Error loading service class %s: %s", $class, $error);
    }

    # Setup locale if defined
    if (my $prefix = ($config->get('locale.prefix') // $config->get('global.locale_directory'))) {
        $self->log->trace('Set locale prefix to '.$prefix);
        set_locale_prefix($prefix);
    }
    if (my $language = ($config->get('locale.language') // $config->get('global.default_language'))) {
        $self->log->trace('Set language to '.$language);
        set_language($language);
    }

    # preparations and checks
    $self->log->trace("Request handling (1/3): preparations and checks");

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
        $self->log->trace("Request handling (2/3): process request");
        $response = $service->handle_request;
        die "Result of $class->handle_request() is not an instance of OpenXPKI::Client::Service::Response"
          unless $response->isa('OpenXPKI::Client::Service::Response');
    }

    # service specific HTTP headers
    $self->res->headers->add($_ => $response->extra_headers->{$_}) for keys $response->extra_headers->%*;

    # status specific code / message
    $self->res->code($response->http_status_code);
    $self->res->message($response->http_status_message);

    # HTTP response
    $self->log->trace("Request handling (3/3): send response");
    try {
        $service->send_response($self, $response);
    }
    catch ($err) {
        $self->log->error($err);
    }

    $service->cleanup if $service->can('cleanup');
}

1;
