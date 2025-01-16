package OpenXPKI::Client::Service::Role::Base;
use OpenXPKI qw( -role -typeconstraints );

requires 'declare_routes';
requires 'prepare';
requires 'send_response';
requires 'op_handlers';
requires 'cgi_set_custom_wf_params';
requires 'prepare_enrollment_result';

=head1 NAME

OpenXPKI::Client::Service::Role::Base - Base role for all HTTP services (i.e.
protocol implementations)

=head1 DESCRIPTION

A consuming class that implements a service generally looks like this:

    package OpenXPKI::Client::Service::TheXProtocol;
    use OpenXPKI -class;

    with 'OpenXPKI::Client::Service::Role::Base';

    # The class needs to define all methods required by C<OpenXPKI::Client::Service::Role::Base>
    sub service_name { 'xproto' }
    sub declare_routes ($r) { ... }
    sub prepare ($self, $c) { ... }
    sub send_response ($self, $c, $response) { ... }
    sub op_handlers { ... }
    sub prepare_enrollment_result ($self, $workflow) { ... }
    sub cgi_set_custom_wf_params ($self) { ... }

=cut

# Core modules
use Carp ();
use MIME::Base64;
use Digest::SHA qw( sha1_hex );
use List::Util qw( any );

# CPAN modules
use Crypt::PKCS10;
use Log::Log4perl qw( :nowarn );
use Mojo::Message::Request;
use Mojo::Util qw( url_unescape );

# Project modules
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Log4perl;


=head2 ATTRIBUTES

=head3 service_name

Internal name of the service that the class implements. Used e.g.

=over

=item * for configuration lookups,

=item * to create the C<Log4perl> logger,

=item * as part of the fallback workflow name in L</handle_property_request>.

=back

=cut
sub service_name; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has service_name => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head3 operation

Defines the requested PKI operation (service specific). Used e.g.

=over

=item * for configuration lookups,

=item * as a lookup key in the mappings returned by L<op_handlers>,

=item * and maybe as part of the fallback workflow name in
L</handle_property_request>.

=back

B<Needs to be set by the consuming class, most likely in its L</prepare> method.>

=cut
sub operation; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has operation => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    predicate => 'has_operation',
    default => sub {
        local $Carp::CarpLevel = 1;
        Carp::confess "Attempt to read empty attribute 'operation'\n";
    },
);

=head2 REQUIRED METHODS

The consuming class needs to implement the following methods:

=head3 prepare

Might contain checks and preparations common to all service operations before
the request handling starts (as defined in L</op_handlers>).

Must set the L</operation> attribute.

Example:

    sub prepare ($self, $c) {
        $self->operation($c->stash('operation'));
        # or
        $self->operation($self->request_param('operation') // '');
    }

B<Parameters>

=over

=item * C<$c> - L<Mojolicious::Controller>

=back

=head3 send_response

Convert the L<OpenXPKI::Client::Service::Response> object into a service
specific HTTP response and send it to the browser via the Mojolicious
controller.

    sub send_response ($self, $c, $response) {
        $self->disconnect_backend;

        if ($response->has_error) {
            return $c->render(text => $response->error_message."\n");

        } else {
            $c->res->headers->content_type('application/xprotocol');
            return $c->render(data => $data);
        }
    }

Please note that the following attributes of the response object are automatically
injected into the Mojolicious response (i.e. C<$c-E<gt>resp>) before C<send_response>
is called:

=over

=item * L<$response-E<gt>extra_headers|OpenXPKI::Client::Service::Response/extra_headers>

=item * L<$response-E<gt>http_status_code|OpenXPKI::Client::Service::Response/http_status_code>

=item * L<$response-E<gt>http_status_message|OpenXPKI::Client::Service::Response/http_status_message>

=back

B<Parameters>

=over

=item * C<$c> - L<Mojolicious::Controller>

=item * C<$response> - L<OpenXPKI::Client::Service::Response>

=back

=head3 op_handlers

Define the mapping between requested operation and the handler methods.

Must return an I<ArrayRef> where the odd items are either an operation name
(I<Str>) or a list of operation names (I<ArrayRef>) and the even items are
I<CodeRefs>.

    sub op_handlers ($self) {
        $self->add_wf_param(server => $self->endpoint);

        return [
            'getcrl' => sub ($self) {
                $self->add_wf_param(mode => $self->xmode);
                $self->handle_property_request('crl');
            },
            ['enroll', 're-enroll'] => \&handle_enrollment_request, # shortcut
            #['enroll','re-enroll'] => $self->can('handle_enrollment_request'), # same
        ];
    }

=head3 cgi_set_custom_wf_params

Legacy method for CGI to add service specific workflow parameters.

    sub cgi_set_custom_wf_params ($self) {
        if ($self->operation eq 'enroll') {
            $self->add_wf_param(server => $self->endpoint);
        }
    }

=head3 prepare_enrollment_result

Service specific processing of the successful enrollment workflow result.

Must return an L<OpenXPKI::Client::Service::Response>.

    sub prepare_enrollment_result ($self, $workflow) {
        return $self->new_response(
            workflow => $workflow,
            result => $workflow->{context}->{cert_identifier},
        );
    }

B<Parameters>

=over

=item * C<$workflow> - workflow info I<HashRef>. Equals the item C<workflow>
in the I<HashRef> returned by
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

=back

=head1 ATTRIBUTES

=head2 Required attributes

These attributes will be set by L<OpenXPKI::Client::Web::Controller> so that
the consuming service class does not need to care about setting them.

=head3 config_obj

An instance of L<OpenXPKI::Client::Config>.

=cut
sub config_obj; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has config_obj => (
    is => 'ro',
    isa => 'OpenXPKI::Client::Config',
    required => 1,
);

=head3 webserver_env

I<HashRef> containing the webserver environment variables (NOT the shell environment).

=cut
sub webserver_env; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has webserver_env => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

=head3 remote_address

IP address of the client that sent the request.

=cut
sub remote_address; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has remote_address => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head3 request

L<Mojo::Message::Request> object encapsulating the request.

=cut
sub request; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has request => (
    is => 'ro',
    isa => 'Mojo::Message::Request',
    required => 1,
    handles => [qw( body_params )],
);

=head3 endpoint

The endpoint I<Str> extracted from the URL.

=cut
sub endpoint; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has endpoint => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 Optional attributes

=head3 take_pickup_value_from_request

Per default (C<0>), the pickup value passed to L<OpenXPKI::Client::Service::Role::PickupWorkflow/pickup_workflow>
is read from the currently configured C<transaction_id> (i.e.
C<$self-E<gt>wf_params-E<gt>{transaction_id}>).

Set this to C<1> to use a custom query parameter as the pickup value instead (C<$self-E<gt>request_param($key)>,
where C<$key> is the current C<rpc.ENDPOINT.OPERATION.pickup>).

=cut
has take_pickup_value_from_request => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

=head2 Other readonly attributes

=head3 config

L<HashRef> containing the endpoint configuration as returned by
L<OpenXPKI::Client::Config/endpoint_config>.

=cut
sub config; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has config => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_config',
);
sub _build_config ($self) { $self->config_obj->endpoint_config($self->endpoint) }

has config_env_keys => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    builder => '_config_env_keys',
);
sub _config_env_keys ($self) {
    my %keys;
    if (my $keys_str = $self->config->{$self->operation}->{env}) {
        %keys = map { $_ => 1 } split /\s*,\s*/, $keys_str;
        $self->log->trace('Configured ENV keys: ' . join(', ', keys %keys)) if $self->log->is_trace;
    }
    return \%keys;
}

=head3 log

A logger object, per default set
C<OpenXPKI::Log4perl-E<gt>get_logger('openxpki.client.' . $self-E<gt>service_name)>.

=cut
sub log; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has log => (
    is => 'rw',
    isa => duck_type( [qw(
           trace    debug    info    warn    error    fatal
        is_trace is_debug is_info is_warn is_error is_fatal
    )] ),
    lazy => 1,
    builder => '_build_log',
);
sub _build_log ($self) { $self->config_obj->log }

=head3 backend

An instance of L<OpenXPKI::Client::Simple> initialized with the current
endpoint configuration.

=cut
sub backend; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has backend => (
    is => 'rw',
    isa => 'Object|Undef',
    init_arg => undef,
    lazy => 1,
    predicate => 'has_backend',
    builder => '_build_backend',
);
sub _build_backend ($self) {
    try {
        return OpenXPKI::Client::Simple->new({
            logger => $self->log,
            config => $self->config->{global}, # realm and locale
            auth => $self->config->{auth} || {}, # auth config
        });
    }
    catch ($err) {
        die $self->new_response( 50002 => "Could not create client object: $err" );
    }
}

=head3 is_enrollment

I<Bool> flag, may be used e.g. in C<custom_wf_params>.

Returns C<1> if L<handle_enrollment_request> was called.

=cut
has is_enrollment => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    default => 0,
);

=head3 default_wf_params

Readonly I<HashRef> with default workflow parameters that is build
automatically.

=cut
has default_wf_params => (
    is => 'ro',
    isa => 'HashRef',
    traits => [ 'Hash' ],
    lazy => 1,
    init_arg => undef,
    builder => '_build_default_wf_params',
    handles => {
        default_wf_param => 'get',
    },

);
sub _build_default_wf_params ($self) {
    try {
        my $p = {};
        my $operation = $self->operation;
        my $conf = $self->config;

        # look for preset params
        foreach my $key (keys %{$conf->{$operation}}) {
            next unless ($key =~ m{preset_(\w+)});
            $p->{$1} = $conf->{$operation}->{$key};
        }

        my $servername = $conf->{$operation}->{servername} || $conf->{global}->{servername};
        if ($servername) {
            $p->{server} = $servername;
            $p->{interface} = $self->service_name;
        }

        $p->{client_ip} = $self->remote_address if $self->config_env_keys->{client_ip};
        $p->{user_agent} = $self->request->headers->user_agent if $self->config_env_keys->{user_agent};
        $p->{endpoint} = $self->endpoint if $self->config_env_keys->{endpoint};

        # be lazy and use endpoint name as servername
        if ($self->config_env_keys->{server}) {
            die "ENV variable 'server' and 'servername' are both set but are mutually exclusive ('servername' might be set global config)\n"
              if $servername;

            $p->{server} = $self->endpoint
              or die "ENV variable 'server' requested but endpoint could not be determined from URL\n";

            $p->{interface} = $self->service_name;
        }

        # gather data from TLS session
        if ( $self->request->is_secure ) {
            $self->log->debug("Calling context is HTTPS");
            $self->log->trace('Webserver ENV keys: ' . join(', ', sort keys $self->webserver_env->%*)) if $self->log->is_trace;

            my $auth_dn = $self->webserver_env->{SSL_CLIENT_S_DN};
            my $auth_pem = $self->webserver_env->{SSL_CLIENT_CERT};
            if ( defined $auth_dn ) {
                $self->log->info("Authenticated client DN: $auth_dn");
                if ($self->config_env_keys->{signer_dn}) {
                    $p->{signer_dn} = $auth_dn;
                }
                if ($auth_pem && $self->config_env_keys->{signer_cert}) {
                    $p->{signer_cert} = $auth_pem;
                }
            } else {
                $self->log->debug("Unauthenticated (no cert)");
            }
        } else {
            $self->log->debug("Calling context is plain HTTP");
        }

        return $p;
    }
    catch ($err) {
        if (blessed $err and $err->isa('OpenXPKI::Client::Service::Response')) {
            die $err;
        } else {
            $self->log->error("$err"); # stringification
            die $self->new_response( 50010 );
        }
    }
}

=head3 wf_params

Readonly I<HashRef> with workflow parameters, incl. L</custom_wf_params>, that
is automatically build.

=cut
has wf_params => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_wf_params',
);
sub _build_wf_params ($self) {
    try {
        # legacy CGI mode
        $self->cgi_set_custom_wf_params if ($ENV{GATEWAY_INTERFACE} and $ENV{REMOTE_ADDR});

        # merge custom parameters set by consuming class
        my $p = {
            $self->default_wf_params->%*,
            $self->custom_wf_params->%*,
        };

        $self->log->trace(sprintf("Parameters for operation '%s': %s", $self->operation, Dumper $p)) if $self->log->is_trace;
        return $p;
    }
    catch ($err) {
        if (blessed $err and $err->isa('OpenXPKI::Client::Service::Response')) {
            die $err;
        } else {
            $self->log->error("$err"); # stringification
            die $self->new_response( 50010 );
        }
    }
}

=head3 custom_wf_params

Custom workflow parameters to be set by the consuming class via L</add_wf_param>.

=cut
has custom_wf_params => (
    is => 'rw',
    isa => 'HashRef',
    traits => [ 'Hash' ],
    lazy => 1,
    init_arg => undef,
    default => sub { {} },
    handles => {
        add_wf_param => 'set',
    },
);

=head3 json

Helper to uniformly access an instance of L<JSON:PP> with the following configuration:

=over

=item * UTF-8 enabled

=item * Use plain scalars as boolean values (when decoding a JSON string)

=back

=cut
sub json; # "stub" subroutine to satisfy "requires" method checks of other consumed roles
has json => (
    is => 'ro',
    isa => 'Object',
    init_arg => undef,
    lazy => 1,
    default => sub {
        my $json = JSON::PP->new->utf8;
        # Use plain scalars as boolean values. The default representation as
        # JSON::PP::Boolean would cause the values to be serialized later on.
        # A JSON false would be converted to a trueish scalar "OXJSF1:false".
        $json->boolean_values(0,1);
        return $json;
    },
);

=head1 METHODS

=cut
# Around modifier with fallback BUILD method:
# "around 'BUILD'" complains if there is no BUILD method in the inheritance
# chain of the consuming class. So we define an empty fallback method.
# If the consuming class defines an own BUILD method it will overwrite ours.
# The "around" modifier will work in any case.
# Please note that "around 'build'" is only allowed in roles.
# https://metacpan.org/dist/Moose/view/lib/Moose/Manual/Construction.pod#BUILD-and-parent-classes
sub BUILD {}
after 'BUILD' => sub ($self, $args) {
    Log::Log4perl::MDC->put('endpoint', $self->endpoint);
    OpenXPKI::Log4perl->set_default_facility($self->config_obj->log_facility);
};

=head2 request_param

Returns the value of the given URL- or POST-parameter.

May be overwritten by the consuming class e.g. to query contents of a JSON request.

B<Parameters>

=over

=item * C<$key> I<Str> - parameter name

=back

=cut
sub request_param ($self, $key) {
    return $self->request->params->param($key);
}

=head2 handle_request

Main request handling method (called by L<OpenXPKI::Client::Web::Controller>):

=over

=item * queries the current operation C<$self-E<gt>operation> (set by consuming class)

=item * calls consuming classes' L</op_handlers>

=item * calls the subroutine returned by L</op_handlers> that matches the operation

=back

B<Returns> an L<OpenXPKI::Client::Service::Response> and does not throw exceptions.

=cut
sub handle_request ($self) {
    $self->log->debug(sprintf('%s request "%s" on endpoint "%s"', uc($self->service_name), $self->operation, $self->endpoint)) if $self->log->is_debug;

    my $response;
    try {
        die $self->new_response( 40008 ) unless $self->operation;

        my $op_handlers = $self->op_handlers;

        die sprintf('%s->op_handlers() did not return an ArrayRef', $self->meta->name)
          unless ref $op_handlers eq 'ARRAY';

        my $i = 0;
        while (my $ops = $op_handlers->[$i++]) {
            # convert ArrayRef / String / Regexp to list of Regexp
            my @op_res = map {
                if (ref $_ eq 'Regexp') {
                    $_;
                } elsif (ref $_ eq '') {
                    qr/\A\Q$_\E\z/;
                } else {
                    die sprintf('Matching rule for handler no. %i in %s->op_handlers() is not an ArrayRef, Regexp or String', $i/2+1, $self->meta->name)
                }
            } ref $ops eq 'ARRAY' ? $ops->@* : ($ops);

            my $handler = $op_handlers->[$i++];

            die sprintf('Handler no. %i in %s->op_handlers() is missing or not a code reference', ($i-1)/2+1, $self->meta->name)
              unless ref $handler eq 'CODE';

            if (any { $self->operation =~ $_  } @op_res) {
                $self->log->trace(sprintf 'Matching rule no. %i in %s->op_handlers(), execute handler', ($i-1)/2+1, $self->meta->name);
                $response = $handler->($self);

                die sprintf('Return value of operation handler for "%s" specified in %s->op_handlers() is not an instance of "OpenXPKI::Client::Service::Response"', $self->operation, $self->meta->name)
                  unless blessed $response && $response->isa('OpenXPKI::Client::Service::Response');

                $response->add_debug_headers if (lc($self->config->{output}->{headers}//'') eq 'all');

                last;
            }
        }

        # error / fallback
        die $self->new_response( 40007 => sprintf('Unknown operation "%s"', $self->operation) )
          unless $response;
    }
    catch ($err) {
        $response = $self->new_error_response($err);
    }

    $self->log->debug('Status: ' . $response->http_status_line);
    $self->log->error($response->error_message) if $response->has_error;

    return $response;
}

=head2 add_wf_param

Allows to add service specific workflow parameters, e.g. in L</op_handlers> or
L</prepare>.

    $self->add_wf_param(server => $self->endpoint) if $self->operation eq 'enroll';

=head2 new_response

Helper to create an C<OpenXPKI::Client::Service::Response> object.

See L<OpenXPKI::Client::Service::Response/new> for syntax details.

=cut
sub new_response ($self, @args) {
    return OpenXPKI::Client::Service::Response->new(@args);
}

=head2 new_error_response

Helper to translate any error into an instance of
L<OpenXPKI::Client::Service::Response>.

    my $response;
    try {
        ...
    }
    catch ($err) {
        $response = $self->new_error_response($err);
    }

Properly detects these error types:

=over

=item * C<OpenXPKI::Client::Service::Response>,

=item * L<C<OpenXPKI::Exception>>,

=item * C<OpenXPKI::Exception::Authentication>,

=item * strings

=back

=cut
sub new_error_response ($self, $error) {
    if (blessed $error) {
        if ($error->isa('OpenXPKI::Client::Service::Response')) {
            return $error;

        } elsif ($error->isa('OpenXPKI::Exception::Authentication')) {
            return $self->new_response(error => 40101, error_message => $error->message);

        } elsif ($error->isa('OpenXPKI::Exception')) {
            return $self->new_response(error => 50000, error_message => $error->message);

        } else {
            return $self->new_response(error => 500, error_message => "$error"); # stringification
        }

    } else {
        return $self->new_response(error => 500, error_message => $error);
    }
}

=head2 new_pending_response

Helper to create a new L<OpenXPKI::Client::Service::Response> from a pending
workflow:

    if ($workflow->{proc_state} ne 'finished') {
        return $self->new_pending_response($workflow);
    }

B<Parameters>

=over

=item * C<$workflow> - workflow info I<HashRef>. Equals the item C<workflow>
in the I<HashRef> returned by
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

=back

=cut
sub new_pending_response ($self, $workflow) {
    my $retry_after;
    if ($workflow->{proc_state} eq 'pause') {
        my $delay = $workflow->{wake_up_at} - time;
        $retry_after = ($delay < 30) ? 30 : $delay;
    } else {
        $retry_after = 300;
    }

    $self->log->info(sprintf 'Request pending - workflow is %s, retry after %ss', $workflow->{'state'}, $retry_after);
    return $self->new_response(
        retry_after => $retry_after,
        workflow => $workflow,
    );
}

=head2 handle_enrollment_request

Handler for enrollment requests.

Tries to pick up an existing enrollment workflow or starts a new one.

The resulting workflow state is checked. If the workflow context contains
a C<cert_identifier> then the consuming classes' L</prepare_enrollment_result>
is called.

B<Returns> an L<OpenXPKI::Client::Service::Response>.

=cut
sub handle_enrollment_request ($self) {
    $self->is_enrollment(1);

    if (not $self->wf_params->{server}) {
        $self->log->error("Parameter 'server' missing but required by enrollment workflow");
        die $self->new_response( 40401 );
    }

    Log::Log4perl::MDC->put('server', $self->wf_params->{server});
    Log::Log4perl::MDC->put('tid', $self->wf_params->{transaction_id});

    #
    # Try pickup
    #
    my $conf = {
        workflow => 'certificate_enroll',
        pickup => 'pkcs10',
        pickup_attribute => 'transaction_id',
        %{ $self->config->{$self->operation} || {} },
    };
    $self->log->trace("Resulting pickup config: " . Dumper $conf) if $self->log->is_trace;

    my $pickup_failed;
    my $workflow;
    try {
        # pickup via workflow
        if (my $wf_type = $conf->{pickup_workflow}) {
            $workflow = $self->pickup_via_workflow($wf_type, $conf->{pickup});

        # pickup via datapool
        } elsif (my $ns = $conf->{pickup_namespace}) {
            $workflow = $self->pickup_via_datapool($ns, $self->wf_params->{transaction_id});

        # pickup via workflow attribute search
        } elsif (my $key = $conf->{pickup_attribute}) {
            $workflow = $self->pickup_via_attribute($conf->{workflow}, $key, $self->wf_params->{transaction_id});
        }
        # only if pickup was done at all and did not die
        if ($workflow) {
            $self->check_workflow_error($workflow);
        }
    }
    catch ($error) {
        if (blessed $error and $error->isa('OpenXPKI::Exception::WorkflowPickupFailed')) {
            $pickup_failed = 1;
        }
        else {
            die $error;
        }
    }

    # exception if pickup failed and there is no PKCS#10 parameter
    if ($pickup_failed and not $self->wf_params->{pkcs10}) {
        $self->log->debug('Workflow pickup failed and no PKCS#10 given');
        die $self->new_response( 40005 );
    }

    #
    # Start new workflow if:
    # a) no pickup parameters found or
    # b) failed pickup, but PKCS#10 given
    #
    if (not $workflow) {
        $self->log->debug(sprintf("Initialize workflow '%s' with parameters: %s",
            $conf->{workflow}, join(", ", keys $self->wf_params->%*)));

        $workflow = $self->run_workflow(
            type => $conf->{workflow},
            params => $self->wf_params,
        );
    }

    # Workflow paused - send "request pending" / ask client to retry
    if ($workflow->{proc_state} ne 'finished') {
        return $self->new_pending_response($workflow);

    # Workflow finished
    } else {
        $self->log->trace('Workflow context: ' . Dumper $workflow->{context}) if $self->log->is_trace;

        my $cert_identifier = $workflow->{context}->{cert_identifier}
            or die $self->new_response(
                error => 40006,
                $workflow->{context}->{error_code} ? (error_message => $workflow->{context}->{error_code}) : (),
                workflow => $workflow,
            );
        $self->log->debug( 'Sending output for ' . $cert_identifier);

        # implemented by consuming class
        return $self->prepare_enrollment_result($workflow);
    }
}

=head2 pickup_via_workflow

Resume a workflow by retrieving its ID via a pickup workflow.

B<Parameters>

=over

=item * C<$wf_type> I<Str> - Workflow type of the pickup workflow

=item * C<$keys_str> I<Str> - Comma separated list of parameter names to read
from C<$self-E<gt>wf_params> or the request parameters and pass to the pickup
workflow

=back

B<Returns> a workflow info I<HashRef> or C<undef> if no workflow was found.

The I<HashRef> equals the item C<workflow> in the I<HashRef> returned by
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

=cut
sub pickup_via_workflow ($self, $wf_type, $keys_str) {
    my $params;
    my @keys = split /\s*,\s*/, $keys_str;
    foreach my $key (@keys) {
        # take value from param hash if defined, this makes data
        # from the environment available to the pickup workflow
        my $val = $self->wf_params->{$key} // $self->request_param($key);
        $params->{$key} = $val if defined $val;
    }

    if (not scalar keys $params->%*) {
        $self->log->debug('Ignoring pickup via workflow: all pickup keys are empty');
        return;
    }
    $self->log->debug(sprintf 'Pickup via workflow "%s" with keys: %s', $wf_type, join(',', @keys));

    my $result = $self->run_workflow(
        type => $wf_type,
        params => $params,
    );
    die "No result from pickup workflow" unless $result->{context};

    $self->log->trace("Pickup workflow result: " . Dumper $result) if $self->log->is_trace;

    return $self->_pickup($result->{context}->{workflow_id});
}

=head2 pickup_via_datapool

Resume a workflow by retrieving its ID from the datapool.

B<Parameters>

=over

=item * C<$namespace> I<Str> - Datapool namespace

=item * C<$key> I<Str> - Datapool key

=back

B<Returns> a workflow info I<HashRef> or C<undef> if no workflow was found.

The I<HashRef> equals the item C<workflow> in the I<HashRef> returned by
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

=cut
sub pickup_via_datapool ($self, $namespace, $key) {
    if (not $key) {
        $self->log->debug('Ignoring pickup via datapool: empty pickup key');
        return;
    }
    $self->log->debug("Pickup via datapool: $namespace.$key" );

    my $wfl = $self->backend->run_command('get_data_pool_entry', {
        namespace => $namespace,
        key => $key,
    });

    return $self->_pickup($wfl->{value});
}

=head2 pickup_via_attribute

Resume a workflow by retrieving its ID with an attribute search (API command
L<search_workflow_instances|OpenXPKI::Server::API2::Plugin::Workflow::search_workflow_instances/search_workflow_instances>).

B<Parameters>

=over

=item * C<$wf_type> I<Str> - type of the workflow to be resumed

=item * C<$key> I<Str> - attribute name

=item * C<$value> I<Str> - attribute value

=back

B<Returns> a workflow info I<HashRef> or C<undef> if no workflow was found.

The I<HashRef> equals the item C<workflow> in the I<HashRef> returned by
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

=cut
sub pickup_via_attribute ($self, $wf_type, $key, $value) {
    if (not $value) {
        $self->log->debug('Ignoring pickup via attribute: empty pickup value');
        return;
    }
    $self->log->debug("Pickup via attribute: $key = $value" );

    my $wfl = $self->backend->run_command('search_workflow_instances', {
        type => $wf_type,
        attribute => { $key => $value },
        limit => 2
    });
    die "Unable to pick up workflow - ambiguous search result" if @$wfl > 1;

    return $self->_pickup(@$wfl == 1 ? $wfl->[0]->{workflow_id} : undef);
}

sub _pickup ($self, $wf_id) {
    if (not $wf_id) {
        $self->log->trace("Cannot pick up workflow: query did not return workflow ID");
        OpenXPKI::Exception::WorkflowPickupFailed->throw;
    }

    if (ref $wf_id or $wf_id !~ m{\A\d+\z}) {
        $self->log->error("Pickup result is not an integer number");
        $self->log->trace(Dumper $wf_id) if $self->log->is_trace;
        OpenXPKI::Exception::WorkflowPickupFailed->throw;
    }

    $self->log->debug("Pick up workflow #${wf_id}");

    my $wf_info = $self->backend->run_command(get_workflow_info => { id => $wf_id });
    if (not $wf_info) {
        $self->log->error("Could not fetch workflow info for workflow #$wf_id");
        OpenXPKI::Exception::WorkflowPickupFailed->throw;
    }
    return $wf_info->{workflow};
}

=head2 handle_property_request

Handler for property requests.

The workflow type is set to:

=over

=item 1 the configuration value C<E<lt>serviceE<gt>.E<lt>operationE<gt>.E<lt>workflowE<gt>> if
specified or

=item 2 the lowercase string C<"E<lt>serviceE<gt>_E<lt>operationE<gt>"> otherwise.

=back

If the workflow ends successfully the contents of its C<output> context key
are returned (wrapped in an L<OpenXPKI::Client::Service::Response>).

B<Parameters>

=over

=item * C<$operation> I<Str> - Optional: operation name (used for querying the
configuration), defaults to C<$self-E<gt>operation>

=back

B<Returns> an L<OpenXPKI::Client::Service::Response>.

=cut
sub handle_property_request ($self, $operation = $self->operation) {
    # TODO - we need to consolidate the workflows for the different protocols
    my $workflow_type = $self->config->{$operation}->{workflow} ||
        $self->service_name.'_'.lc($operation);

    my $response = $self->new_response(
        workflow => $self->run_workflow(type => $workflow_type, params => $self->wf_params)
    );

    return $response if $response->has_error;

    if ($response->workflow->{context}->{output}) {
        $response->result( $response->workflow()->{context}->{output} );
    } else {
        $response->error( 50003 );
    }

    return $response;
}

=head2 run_workflow

Runs the given workflow type with the given parameters via
L<OpenXPKI::Client::Simple/handle_workflow>.

B<Parameters>

=over

=item * C<%args> I<Hash> - arguments to pass to C<handle_workflow>

=back

B<Returns> a workflow info I<HashRef>. The I<HashRef> equals the item
C<workflow> in the I<HashRef> returned by
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

Throws an L<OpenXPKI::Client::Service::Response> in case of errors.

=cut
sub run_workflow ($self, %args) {
    # create the client object
    my $client = $self->backend;
    my $wf_info;

    try {
        $wf_info = $client->handle_workflow(\%args);
    }
    catch ($err) {
        $self->log->error($err);
        $self->check_workflow_error(undef, $err);
        die $self->new_error_response( 50003 ); # fallback
    }

    $self->check_workflow_error($wf_info);
    return $wf_info;
}

# Checks the given workflow result I<HashRef> and dies with a
# L<OpenXPKI::Client::Service::Response> in case of workflow errors.
#
# If L<OpenXPKI::Client::Simple/last_error> returns a string starting with
# C<"I18N_OPENXPKI_UI_"> it is added to the error message (this filtering is done
# in L</new_response>).
#
# B<Parameters>
#
# =over
#
# =item * C<$workflow> - workflow info I<HashRef>. Equals the item C<workflow>
# in the I<HashRef> returned by
# L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.
#
# =back
#
# B<Returns> nothing if successful.
sub check_workflow_error ($self, $workflow, $error = '') {
    $self->log->trace('Workflow result: '  . Dumper $workflow) if ($workflow and $self->log->is_trace);

    if (
        not $workflow
        or ($workflow->{'proc_state'} ne 'finished' and not $workflow->{id})
        or ($workflow->{'proc_state'} eq 'exception')
    ) {
        my $reply = $self->backend->last_reply || {};
        # this is assembled in OpenXPKI::Service::Default->__send_error():
        if (my $err = $reply->{ERROR}) {
            if (my $class = $err->{CLASS}) {
                if ($class eq 'OpenXPKI::Exception::InputValidator') {
                    $self->log->info( 'Input validation failed' );

                    my @fields = map { $_->{name} } ($err->{ERRORS} // {})->@*;
                    $self->log->info( 'Failed fields: ' . join(', ', @fields) ) if scalar @fields;

                    die $self->new_response(
                        error => 40004,
                        $error ? (error_message => $error) : (),
                        $workflow ? (workflow => $workflow) : (),
                        error_details => { fields => $reply->{ERROR}->{ERRORS} // [] },
                    );
                }
            }
        }

        my $msg = $self->backend->last_error || $error;
        die $self->new_response(
            error => 50003,
            $msg ? (error_message => $msg) : (),
            $workflow ? (workflow => $workflow) : (),
        );
    }
}

=head2 disconnect_backend

Disconnect the backend (client) if it was initialized.

B<Returns> nothing and does not throw exceptions.

=cut
sub disconnect_backend ($self) {
    return unless $self->has_backend;
    eval { $self->backend->disconnect if $self->backend };
}

=head2 set_pkcs10_and_tid

Sets the C<pkcs10> custom workflow parameter to the PEM CSR after conversion
rountrip and removal of any data beyond the length of the ASN.1 structure.

Also sets the C<transaction_id> parameter to the hexadecimal SHA1 hash
(L<Digest::SHA/sha1_hex>) of the binary CSR.

B<Parameters>

=over

=item * C<$pkcs10> I<Str> - PKCS10 encoded CSR

=back

B<Returns> nothing.

=cut
sub set_pkcs10_and_tid ($self, $pkcs10 = undef) {
    $self->log->debug('Parse PKCS10');

    # Usually PEM encoded but without borders as POSTDATA
    $pkcs10 or do {
        $self->log->debug( 'Incoming enrollment with empty body' );
        die $self->new_response( 40003 );
    };

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new($pkcs10, ignoreNonBase64 => 1, verifySignature => 1);
    if (!$decoded) {
        $self->log->error('Unable to parse PKCS10: '. Crypt::PKCS10->error);
        $self->log->debug($pkcs10);
        die $self->new_response( 40002 );
    }

    $self->add_wf_param(pkcs10 =>$decoded->csrRequest(1));
    $self->add_wf_param(transaction_id => sha1_hex($decoded->csrRequest));
}

=head1 LEGACY CGI METHODS

=head2 cgi_to_mojo_request

Parses a CGI environment into a L<Mojo::Message::Request> object.

B<Returns> A L<Mojo::Message::Request> object.

=cut
sub cgi_to_mojo_request {
    my $req = Mojo::Message::Request->new->parse(\%ENV);

    # Request body (may block if we try to read too much)
    binmode STDIN;
    my $len = $req->headers->content_length;
    until ($req->is_finished) {
        my $chunk = ($len && $len < 131072) ? $len : 131072;
        last unless my $read = STDIN->read(my $buffer, $chunk, 0);
        $req->parse($buffer);
        last if ($len -= $read) <= 0;
    }

    return $req;
}

=head2 cgi_safe_sub

Class method to wrap legacy CGI request handling in a try-catch block so that
always an L<OpenXPKI::Client::Service::Response> is returned.

=cut
sub cgi_safe_sub :prototype($&) ($self, $handler_sub) {
    my $response;
    try {
        $response = $handler_sub->();
    }
    catch ($err) {
        $response = $self->new_error_response($err);
    }

    $self->log->debug('HTTP status: [' . $response->http_status_line . ']');
    $self->log->error($response->error_message) if $response->has_error;

    return $response;
}

=head2 cgi_headers

Converts standard HTTP header names to parameters that can be passed to
L<CGI/header>.

B<Parameters>

=over

=item * C<$headers> I<HashRef> - headers where the keys are HTTP standard names (i.e. C<"content-type">)

=back

B<Returns> a I<HashRef> with headers where the keys are L<CGI> specific names (i.e. C<"-type">)

=cut
sub cgi_headers ($self, $headers) {
    my @keys = keys $headers->%*;
    my @values = values $headers->%*;

    my @cgi_keys =
        map { ($_ eq '-content_type') ? '-type' : $_ }
        map { lc }
        map { "-$_" }
        map { s/-/_/g; $_ }
        @keys;

    my %cgi_headers;
    @cgi_headers{@cgi_keys} = @values;
    return \%cgi_headers;
}

1;
