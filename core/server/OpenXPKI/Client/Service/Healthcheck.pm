package OpenXPKI::Client::Service::Healthcheck;
use OpenXPKI -class;

with qw(
    OpenXPKI::Client::Service::Role::Info
    OpenXPKI::Client::Service::Role::Base
);

# Core modules
use List::Util qw( any );

# Project modules
use OpenXPKI::Client;


has allowed_commands => (
    is => 'rw',
    isa => 'ArrayRef',
    traits => ['Array'],
    lazy => 1,
    handles => {
        add_allowed_command => 'push',
    },
    default => sub { [ '' ] },
);

# required by OpenXPKI::Client::Service::Role::Info
sub declare_routes ($r) {
    $r->get('/healthcheck' => sub { shift->redirect_to('check', command => 'ping') });
    $r->get('/healthcheck/<command>')->to(
        service_class => __PACKAGE__,
        endpoint => 'default',
        no_config => 1,
    )->name('check');
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare ($self, $c) {
    my $command = $c->stash('command');
    $self->operation($command);

    # Add commands defined in the config file
    $self->add_allowed_command($self->config->get_keys());

    # more allowed commands in OPENXPKI_HEALTHCHECK ?
    if ($ENV{OPENXPKI_HEALTHCHECK}) {
        my @allowed = split /\W+/, $ENV{OPENXPKI_HEALTHCHECK};
        $self->log->debug('Add allowed commands: ' . join(' / ', @allowed));
        $self->add_allowed_command(@allowed);
    }

    # check if command allowed
    die $self->new_response( 40006 => sprintf('Command "%s" not allowed', $command) )
        unless any { $command eq $_ } $self->allowed_commands->@*;
}

# required by OpenXPKI::Client::Service::Role::Base
sub send_response ($self, $c, $response) {
    $c->set_response_headers($response);
    return $c->render(
        json => $response->has_result
            ? $response->result
            : { error => $response->has_error ? $response->error_message : 'Unknown error' }
    );
}

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers {
    return [
        # Do NOT expose this unless you are in a test environment.
        'showenv' => sub ($self) {
            return $self->new_response( result => {
                system => \%ENV,
                mapped => $self->request->env,
            });
        },
        'ping' => sub ($self) {
            # CAVE: the client is shared with the WebUI across all requests of
            # this worker (see OpenXPKI::Client::Web helper "oxi_client"), so we
            # must not create a session or close the connection here - the first
            # would leave an orphaned session behind on every poll, the second
            # would force the next WebUI request to reconnect.
            # A successful PING already proves that socket, transport,
            # serialization and service protocol are working.
            try {
                $self->client->send_receive_service_msg('PING');
                $self->log->trace('Ping OK');
                return $self->new_response(result => { ping => 1 });
            }
            catch ($err) {
                $self->log->error("Ping failed: $err");
                return $self->new_response(result => { ping => 0 }, error => 500);
            }
        },
    ];
}

# required by OpenXPKI::Client::Service::Role::Base
sub cgi_set_custom_wf_params {}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result {}

__PACKAGE__->meta->make_immutable;
