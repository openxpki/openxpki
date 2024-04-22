package OpenXPKI::Client::Service::Role::Base;
use OpenXPKI qw( -role -typeconstraints );

with 'OpenXPKI::Client::Service::Role::PickupWorkflow';

requires 'service_name';
requires 'prepare';
requires 'send_response';
requires 'op_handlers';
requires 'fcgi_set_custom_wf_params';
requires 'prepare_enrollment_result';

=head1 NAME

OpenXPKI::Client::Service::Role::Base - Base role for all service classes (i.e.
protocol implementations)

=head1 DESCRIPTION

A consuming class that implements a service generally looks like this:

    package OpenXPKI::Client::Service::TheXProtocol;
    use OpenXPKI -class;

    with 'OpenXPKI::Client::Service::Role::Base';

    # The class needs to define all methods required by C<OpenXPKI::Client::Service::Role::Base>
    sub service_name { 'xproto' }
    sub prepare ($self, $c) { ... }
    sub send_response ($self, $c, $response) { ... }
    sub op_handlers { ... }
    sub prepare_enrollment_result ($self, $workflow) { ... }
    sub fcgi_set_custom_wf_params ($self) { ... }

=cut

# Core modules
use Carp;
use MIME::Base64;
use Digest::SHA qw( sha1_hex );
use List::Util qw( first );
use Exporter qw( import );

# CPAN modules
use Crypt::PKCS10;
use Log::Log4perl qw( :nowarn );
use Mojo::Message::Request;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Log4perl;


# Symbols to export by default
# (we avoid Moose::Exporter's import magic because that switches on all warnings again)
our @EXPORT = qw( cgi_safe_sub );

=head2 ATTRIBUTES

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
has operation => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { die "Attribute 'operation' has not been set" },
);

=head2 REQUIRED METHODS

The consuming class needs to implement the following methods.

=head3 service_name

Name of the service the class implements. Used e.g.

=over

=item * for configuration lookups,

=item * to create the C<Log4perl> logger,

=item * as part of the fallback workflow name in L</handle_property_request>.

=back

    sub service_name { 'xproto' }

=head3 prepare

Should be used to set the L</operation> attribute.

    sub prepare ($self, $c) {
        # e.g.
        $self->operation($c->stash('operation'));
        # or
        $self->operation($self->query_params->param('operation') // '');
    }

May also be used to checks and preparations before the request / operation
handling as defined in L</op_handlers>.

=head3 send_response

Sends the response back to the HTTP client via a passed Mojolicious controller.

    sub send_response ($self, $c, $response) {
        $self->disconnect_backend;

        if ($response->has_error) {
            return $c->render(text => $response->error_message."\n");

        } else {
            $c->res->headers->content_type('application/xprotocol');
            return $c->render(data => $data);
        }
    }

=head3 op_handlers

Defines the mapping between requested operation and the handler methods.

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
        ];
    }

=head3 fcgi_set_custom_wf_params

Legacy method for CGI to add service specific workflow parameters.

    sub fcgi_set_custom_wf_params ($self) {
        if ($self->operation eq 'enroll') {
            $self->add_wf_param(server => $self->endpoint);
        }
    }

=head3 prepare_enrollment_result

Service specific processing of the successful enrollment workflow result.

Must return an L<OpenXPKI::Client::Service::Response>.

    sub prepare_enrollment_result ($self, $workflow) {
        return OpenXPKI::Client::Service::Response->new(
            workflow => $workflow,
            result => $workflow->{context}->{cert_identifier},
        );
    }

=head1 ATTRIBUTES

=head2 REQUIRED

These attributes will be set by L<OpenXPKI::Client::Web::Controller> so that
the consuming service class does not need to care about setting them.

=head3 config_obj

An instance of L<OpenXPKI::Client::Config>.

=cut
has config_obj => (
    is => 'ro',
    isa => 'OpenXPKI::Client::Config',
    required => 1,
);

=head3 apache_env

I<HashRef> containing the Apache environment variables (NOT the shell environment).

=cut
has apache_env => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

=head3 remote_address

IP address of the client that sent the request.

=cut
has remote_address => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head3 remote_address

L<Mojo::Message::Request> object encapsulating the request.

=cut
has request => (
    is => 'ro',
    isa => 'Mojo::Message::Request',
    required => 1,
    handles => [qw( query_params body_params )],
);

=head3 endpoint

The endpoint I<Str> extracted from the URL.

=cut
has endpoint => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 OTHER

=head3 config

L<HashRef> containing the endpoint configuration as returned by
L<OpenXPKI::Client::Config/endpoint_config>.

=cut
has config => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_config',
);
sub _build_config ($self) { $self->config_obj->endpoint_config($self->endpoint) }

=head3 log

A logger object, per default set
C<OpenXPKI::Log4perl-E<gt>get_logger('client.' . $self-E<gt>service_name)>.

=cut
has log => (
    is => 'rw',
    isa => duck_type( [qw(
           trace    debug    info    warn    error    fatal
        is_trace is_debug is_info is_warn is_error is_fatal
    )] ),
    lazy => 1,
    builder => '_build_log',
);
sub _build_log ($self) { OpenXPKI::Log4perl->get_logger('client.' . $self->service_name) }

=head3 backend

An instance of L<OpenXPKI::Client::Simple> initialized with the current
endpoint configuration.

=cut
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
        $self->log->error("Could not create client object: $err");
        die OpenXPKI::Client::Service::Response->new_error( 50001 );
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
            $p->{'server'} = $servername;
            $p->{'interface'} = $self->service_name;
        }

        my %envkeys;
        if ($conf->{$operation}->{env}) {
            %envkeys = map {$_ => 1} (split /\s*,\s*/, $conf->{$operation}->{env});
            $self->log->trace("Found env keys: " . $conf->{$operation}->{env});
        }

        $p->{'client_ip'} = $self->remote_address if $envkeys{'client_ip'};
        $p->{'user_agent'} = $self->request->headers->user_agent if $envkeys{'user_agent'};
        $p->{'endpoint'} = $self->endpoint if $envkeys{'endpoint'};

        # be lazy and use endpoint name as servername
        if ($envkeys{'server'}) {
            die "ENV 'server' and 'servername' are both set but are mutually exclusive ('servername' might be set global config)\n"
              if $servername;

            $p->{'server'} = $self->endpoint
              or die "ENV 'server' requested but endpoint is not set\n";

            $p->{'interface'} = $self->service_name;
        }

        # gather data from TLS session
        if ( $self->request->is_secure ) {
            $self->log->debug("calling context is https");
            my $auth_dn = $self->apache_env->{SSL_CLIENT_S_DN};
            my $auth_pem = $self->apache_env->{SSL_CLIENT_CERT};
            if ( defined $auth_dn ) {
                $self->log->info("authenticated client DN: $auth_dn");
                if ($envkeys{'signer_dn'}) {
                    $p->{'signer_dn'} = $auth_dn;
                }
                if ($auth_pem && $envkeys{'signer_cert'}) {
                    $p->{'signer_cert'} = $auth_pem;
                }
            } else {
                $self->log->debug("unauthenticated (no cert)");
            }
        }

        # legacy CGI mode
        $self->fcgi_set_custom_wf_params if ($ENV{GATEWAY_INTERFACE} and $ENV{REMOTE_ADDR});

        # merge custom parameters set by consuming class
        $p = {
            $p->%*,
            $self->custom_wf_params->%*,
        };

        $self->log->trace(sprintf("Parameters for operation '%s': %s", $self->operation, Dumper $p)) if $self->log->is_trace;
        return $p;
    }
    catch ($err) {
        if ($err->isa('OpenXPKI::Client::Service::Response')) {
            die $err;
        } else {
            die OpenXPKI::Client::Service::Response->new_error( 50010 => "$err" ); # stringification
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
};

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
    $self->log->debug(sprintf('Incoming %s request "%s" on endpoint "%s"', uc($self->service_name), $self->operation, $self->endpoint)) if $self->log->is_debug;

    my $response;
    try {
        die OpenXPKI::Client::Service::Response->new_error( 40008 ) unless $self->operation;

        my $op_handlers = $self->op_handlers;

        die sprintf('%s->op_handlers() did not return an ArrayRef', $self->meta->name)
          unless ref $op_handlers eq 'ARRAY';

        my $i = 0;
        while (my $ops = $op_handlers->[$i++]) {
            $ops = ref $ops eq 'ARRAY' ? $ops : [ $ops ];
            my $handler = $op_handlers->[$i++];

            die sprintf('Handler for "%s" in %s->op_handlers() is missing or not a code reference', join(',', $ops->@*), $self->meta->name)
              unless ref $handler eq 'CODE';

            if (my $op = first { $_ eq $self->operation } $ops->@*) {
                $response = $handler->($self);

                die sprintf('Return value of operation handler for "%s" specified in %s->op_handlers() is not an instance of "OpenXPKI::Client::Service::Response"', $self->operation, $self->meta->name)
                  unless blessed $response && $response->isa('OpenXPKI::Client::Service::Response');

                $response->add_debug_headers if (lc($self->config->{output}->{headers}//'') eq 'all');

                last;
            }
        }

        # error / fallback
        $response //= OpenXPKI::Client::Service::Response->new_error(
            40007 => sprintf('Unknown operation "%s"', $self->operation)
        );
    }
    catch ($err) {
        if ($err->isa('OpenXPKI::Client::Service::Response')) {
            $response = $err;
        } else {
            $response = OpenXPKI::Client::Service::Response->new_error(500 => "$err"); # stringification
        }
    }

    $self->log->debug('Status: ' . $response->http_status_line);
    $self->log->error($response->error_message) if $response->has_error;
    $self->log->trace(Dumper $response) if $self->log->is_trace;

    return $response;
}

=head2 add_wf_param

Allows to add service specific workflow parameters, e.g. in L</op_handlers> or
L</prepare>.

    $self->add_wf_param(server => $self->endpoint) if $self->operation eq 'enroll';

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

    # Build configuration parameters. May be customized by service classes
    # via add_wf_param(), e.g. for SCEP to inject data from the input.
    my $param = $self->wf_params;

    if (not $param->{server}) {
        $self->log->error("Parameter 'server' missing but required by enrollment workflow");
        return OpenXPKI::Client::Service::Response->new_error( 40401 );
    }
    Log::Log4perl::MDC->put('server', $param->{server});

    # create the client object
    my $client = $self->backend;

    my ($pickup_config, $pickup_value) = $self->_build_pickup_config;
    $self->log->trace(Dumper $pickup_config) if $self->log->is_trace;

    my $workflow;

    try {
        # try pickup
        $workflow = $self->pickup_workflow($pickup_config, $pickup_value);

        # it was a pickup, it was not successful, we do not have a PKCS10
        if ($pickup_value and not $workflow and not $param->{pkcs10}) {
            $self->log->debug("Pickup failed and no PKCS10 given");
            return OpenXPKI::Client::Service::Response->new_error( 40005 );
        }

        # pickup return undef if no workflow was found - start new one
        if (not $workflow) {
            $self->log->debug(sprintf("Initialize workflow '%s' with parameters: %s",
                $pickup_config->{workflow}, join(", ", keys %{$param})));

            $workflow = $client->handle_workflow({
                type => $pickup_config->{workflow},
                params => $param,
            });
        }
    }
    catch ($error) {
        $self->log->error( $error );
        return OpenXPKI::Client::Service::Response->new_error( 50003 );
    }

    $self->check_workflow_error($workflow);

    if ($workflow->{'proc_state'} ne 'finished') {
        my $retry_after = 300;
        if ($workflow->{'proc_state'} eq 'pause') {
            my $delay = $workflow->{'wake_up_at'} - time();
            $retry_after = ($delay > 30) ? $delay : 30;
        }

        $self->log->info('Request Pending - ' . $workflow->{'state'});
        return OpenXPKI::Client::Service::Response->new(
            retry_after => $retry_after,
            workflow => $workflow,
        );
    }

    $self->log->trace(Dumper $workflow->{context}) if $self->log->is_trace;

    my $cert_identifier = $workflow->{context}->{cert_identifier};

    if (!$cert_identifier) {
        return OpenXPKI::Client::Service::Response->new(
            error => 40006,
            ($workflow->{context}->{error_code} ? (error_message => $workflow->{context}->{error_code}) : ()),
            workflow => $workflow,
        );
    }

    $self->log->debug( 'Sending output for ' . $cert_identifier);

    # implemented by consuming class
    return $self->prepare_enrollment_result($workflow);
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
    my $param = $self->wf_params;

    # TODO - we need to consolidate the workflows for the different protocols
    my $workflow_type = $self->config->{$operation}->{workflow} ||
        $self->service_name.'_'.lc($operation);

    my $response = $self->run_workflow($workflow_type, $param);

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

=item * C<$workflow_type> I<Str> - workflow type

=item * C<$param> I<HashRef> - workflow parameters

=back

B<Returns> an L<OpenXPKI::Client::Service::Response>.

=cut
sub run_workflow ($self, $workflow_type, $param) {
    $self->log->debug( "Start workflow type '$workflow_type'" );
    $self->log->trace( 'Workflow parameters: '  . Dumper $param ) if $self->log->is_trace;

    # create the client object
    my $client = $self->backend;
    my $workflow;

    try {
        $workflow = $client->handle_workflow({
            type => $workflow_type,
            params => $param
        });
    }
    catch ($err) {
        $self->log->error($err);
        return OpenXPKI::Client::Service::Response->new_error( 50003 );
    }

    $self->check_workflow_error($workflow);

    return OpenXPKI::Client::Service::Response->new(
        workflow => $workflow,
    );
}

=head2 check_workflow_error

Checks the given workflow result I<HashRef> and dies with a
L<OpenXPKI::Client::Service::Response> in case of workflow errors.

B<Parameters>

=over

=item * C<$workflow> I<HashRef> - workflow information as returned by
L<OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info>

=back

B<Returns> nothing if successful.

=cut
sub check_workflow_error ($self, $workflow) {
    $self->log->trace( 'Workflow result: '  . Dumper $workflow ) if $self->log->is_trace;

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
                    die OpenXPKI::Client::Service::Response->new_error( 40004 );
                }
            }
            $self->log->error( 'Internal server error: ' . $err->{LABEL} );
        } else {
            $self->log->error( 'Internal server error' );
        }
        die OpenXPKI::Client::Service::Response->new_error( 50003 );
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
        die OpenXPKI::Client::Service::Response->new_error( 40003 );
    };

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new($pkcs10, ignoreNonBase64 => 1, verifySignature => 1);
    if (!$decoded) {
        $self->log->error('Unable to parse PKCS10: '. Crypt::PKCS10->error);
        $self->log->debug($pkcs10);
        die OpenXPKI::Client::Service::Response->new_error( 40002 );
    }

    $self->add_wf_param(pkcs10 =>$decoded->csrRequest(1));
    $self->add_wf_param(transaction_id => sha1_hex($decoded->csrRequest));
}

=head2 _build_pickup_config

Build a configuration hash for the pickup workflow from

=over

=item * L</wf_params> and

=item * the services' configuration for the current operation.

=back

B<Returns> A list C<($config, $value)>:

=over

=item * C<$config> - Pickup workflow configuration I<HashRef>

=item * C<$value> - Pickup parameter I<HashRef> if C<$config-E<gt>{pickup_workflow}> is given, or transaction ID value I<Str> otherwise

=back

=cut
sub _build_pickup_config ($self) {
    my $conf = $self->config;
    my $param = $self->wf_params;

    my $pickup_config = {
        workflow => 'certificate_enroll',
        pickup => 'pkcs10',
        pickup_attribute => 'transaction_id',
        %{$conf->{$self->operation} || {}},
    };

    Log::Log4perl::MDC->put('tid', $param->{transaction_id});

    # check for pickup parameter
    my $pickup_value;
    # namespace needs a single value
    if ($pickup_config->{pickup_workflow}) {
        # explicit pickup paramters are set
        my @keys = split /\s*,\s*/, $pickup_config->{pickup};
        foreach my $key (@keys) {
            # take value from param hash if defined, this makes data
            # from the environment available to the pickup workflow
            my $val = $param->{$key} // $self->request->param($key);
            $pickup_value->{$key} = $val if (defined $val);
        }
    } else {
        # pickup via transaction_id
        $pickup_value = $param->{transaction_id};
    }

    return ($pickup_config, $pickup_value);
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
sub cgi_safe_sub :prototype(&) {

    my $handler_sub = shift;

    my $response;
    try {
        $response = $handler_sub->();
    }
    catch ($err) {
        if ($err->isa('OpenXPKI::Client::Service::Response')) {
            $response = $err;
        } else {
            $response = OpenXPKI::Client::Service::Response->new_error( 500 => "$err" ); # stringification
        }
    }

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

__END__;
