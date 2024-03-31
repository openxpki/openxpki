package OpenXPKI::Client::Service::Role::Base;
use OpenXPKI qw( -role -exporter -typeconstraints );

with 'OpenXPKI::Client::Service::Role::PickupWorkflow';

requires 'service_name';
requires 'prepare';
requires 'send_response';
requires 'op_handlers';
requires 'custom_wf_params';
requires 'prepare_enrollment_result';

# Core modules
use Carp;
use MIME::Base64;
use Digest::SHA qw( sha1_hex );
use List::Util qw( first );

# CPAN modules
use Crypt::PKCS10;
use Log::Log4perl qw( :nowarn );
use Mojo::Message::Request;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Log4perl;


Moose::Exporter->setup_import_methods(
    as_is => [ 'fcgi_safe_sub' ],
);

# required parameters
has config_obj => (
    is => 'ro',
    isa => 'OpenXPKI::Client::Config',
    required => 1,
);

has apache_env => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

has remote_address => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has request => (
    is => 'ro',
    isa => 'Mojo::Message::Request',
    required => 1,
    handles => [qw( query_params body_params )],
);

has endpoint => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

# the endpoint config
has config => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_config',
);
sub _build_config ($self) { $self->config_obj->endpoint_config($self->endpoint) }

has operation => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { die "Attribute 'operation' has not been set" },
);

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

has backend => (
    is => 'rw',
    isa => 'Object|Undef',
    init_arg => undef,
    lazy => 1,
    predicate => 'has_backend',
    builder => '_build_backend',
);
sub _build_backend ($self) {
    OpenXPKI::Client::Simple->new({
        logger => $self->log,
        config => $self->config->{global}, # realm and locale
        auth => $self->config->{auth} || {}, # auth config
    })
}

has is_enrollment => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    default => 0,
);

# Workflow parameters. A value of "undef" indicates an error.
has wf_params => (
    is => 'ro',
    isa => 'HashRef|Undef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_wf_params',
);
sub _build_wf_params {

    my $self = shift;

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
        # if given, append to the paramter list
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

        # Gather data from TLS session
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

        # hook that allows consuming classes to add own parameters
        $self->custom_wf_params($p);

        $self->log->trace(sprintf("Extra params for operation '%s': %s", $self->operation, Dumper $p)) if $self->log->is_trace;
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

# Around modifier with fallback BUILD method:
# "around 'BUILD'" complains if there is no BUILD method in the inheritance
# chain of the consuming class. So we define an empty fallback method.
# If the consuming class defines an own BUILD method it will overwrite ours.
# The "around" modifier will work in any case.
# Please note that "around 'build'" is only allowed in roles.
# https://metacpan.org/dist/Moose/view/lib/Moose/Manual/Construction.pod#BUILD-and-parent-classes
sub BUILD {}
after 'BUILD' => sub {
    my $self = shift;
    Log::Log4perl::MDC->put('endpoint', $self->endpoint);
};

# Returns the request as PEM CSR after conversion rountrip and removal of any
# data beyond the length of the ASN.1 structure.
# Sending PEM with headers is not allowed in neither one but will be
# gracefully accepted and converted by Crypt::PKSC10.
sub set_pkcs10_and_tid {

    my $self = shift;
    my $params = shift;

    # Usually PEM encoded but without borders as POSTDATA
    my $pkcs10_in = shift
        or do {
            $self->log->debug( 'Incoming enrollment with empty body' );
            die OpenXPKI::Client::Service::Response->new( 40003 );
        };

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new($pkcs10_in, ignoreNonBase64 => 1, verifySignature => 1);
    if (!$decoded) {
        $self->log->error('Unable to parse PKCS10: '. Crypt::PKCS10->error);
        $self->log->debug($pkcs10_in);
        die OpenXPKI::Client::Service::Response->new( 40002 );
    }

    $params->{pkcs10} = $decoded->csrRequest(1);
    $params->{transaction_id} = sha1_hex($decoded->csrRequest);
}

sub build_pickup_config {

    my $self = shift;
    my $param = shift;

    my $conf = $self->config;
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
            # from the environment avail to the pickup workflow
            my $val = $param->{$key} // $self->request->param($key);
            $pickup_value->{$key} = $val if (defined $val);
        }
    } else {
        # pickup via transaction_id
        $pickup_value = $param->{transaction_id};
    }

    return ($pickup_config, $pickup_value);
}

# Class method to wrap legacy FCGI request handling in a try-catch block
sub fcgi_safe_sub :prototype(&) {

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

sub handle_request {

    my $self = shift;

    $self->log->debug(sprintf('Incoming %s request "%s" on endpoint "%s"', uc($self->service_name), $self->operation, $self->endpoint)) if $self->log->is_debug;

    my $response;
    try {
        die OpenXPKI::Client::Service::Response->new( 40008 ) unless $self->operation;

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

                last;

                # if ($ep_config->{output}->{headers}) {
                #     $self->headers->add($_ => $response->extra_headers->{$_}) for keys $response->extra_headers->%*;
                # }
            }
        }

        # error / fallback
        $response //= OpenXPKI::Client::Service::Response->new(
            error => 40007,
            error_message => sprintf('Unknown operation "%s"', $self->operation),
        );
    }
    catch ($err) {
        if ($err->isa('OpenXPKI::Client::Service::Response')) {
            $response = $err;
        } else {
            $response = OpenXPKI::Client::Service::Response->new(
                error => 50000,
                error_message => "$err", # stringification
            );
        }
    }

    $self->log->debug('Status: ' . $response->http_status_line);
    $self->log->error($response->error_message) if $response->has_error;
    $self->log->trace(Dumper $response) if $self->log->is_trace;

    return $response;
}

sub handle_enrollment_request ($self) {
    $self->is_enrollment(1);

    # Build configuration parameters. May be customized by protocol classes
    # via custom_wf_params(), e.g. for SCEP to inject data from the input.
    my $param = $self->wf_params;

    if (not $param->{server}) {
        $self->log->error("Parameter 'server' missing but required by enrollment workflow");
        return OpenXPKI::Client::Service::Response->new( 40401 );
    }
    Log::Log4perl::MDC->put('server', $param->{server});

    # create the client object
    my $client = $self->backend
        or return OpenXPKI::Client::Service::Response->new( 50001 );

    my ($pickup_config, $pickup_value) = $self->build_pickup_config( $param );
    $self->log->trace(Dumper $pickup_config) if $self->log->is_trace;

    my $workflow;

    try {
        # try pickup
        $workflow = $self->pickup_workflow($pickup_config, $pickup_value);

        # it was a pickup, it was not successful, we do not have a PKCS10
        if ($pickup_value and not $workflow and not $param->{pkcs10}) {
            $self->log->debug("Pickup failed and no PKCS10 given");
            return OpenXPKI::Client::Service::Response->new( 40005 );
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

        $self->log->trace( 'Workflow info: '  . Dumper $workflow ) if $self->log->is_trace;
    }
    catch ($error) {
        $self->log->error( $error );
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

    if (!$workflow || ( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {
        my $reply = $client->last_reply() || {};
        if (my $err = $reply->{ERROR}) {
            if ($err->{CLASS} eq 'OpenXPKI::Exception::InputValidator') {
                $self->log->info( 'Input validation failed' );
                return OpenXPKI::Client::Service::Response->new( 40004 );
            }
        }
        $self->log->error( 'Internal server error');
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

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

sub handle_property_request ($self, $operation = $self->operation) {
    my $param = $self->wf_params;

    # TODO - we need to consolidate the workflows for the different protocols
    my $workflow_type = $self->config->{$operation}->{workflow} ||
        $self->service_name.'_'.lc($operation);
    $self->log->debug( "Start workflow type '$workflow_type'" );
    $self->log->trace( 'Workflow parameters: '  . Dumper $param ) if $self->log->is_trace;

    my $response = $self->run_workflow($workflow_type, $param);

    return $self->_handle_property_response($response);
}

sub run_workflow {

    my $self = shift;
    my $workflow_type = shift;
    my $param = shift;

    # create the client object
    my $client = $self->backend
        or return OpenXPKI::Client::Service::Response->new( 50001 );

    my $workflow = $client->handle_workflow({
        type => $workflow_type,
        params => $param
    });

    $self->log->trace( 'Workflow info: '  . Dumper $workflow ) if $self->log->is_trace;

    if (!$workflow || ( $workflow->{'proc_state'} !~ m{finished|manual} )) {
        if (my $err = $client->last_reply()->{ERROR}) {
            if ($err->{CLASS} eq 'OpenXPKI::Exception::InputValidator') {
                $self->log->info( 'Input validation failed' );
                return OpenXPKI::Client::Service::Response->new( 40004 );
            }
        }
        $self->log->error( $EVAL_ERROR ? $EVAL_ERROR : 'Internal Server Error' );
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

    return OpenXPKI::Client::Service::Response->new(
        workflow => $workflow,
    );

}

sub _handle_property_response {

    my $self = shift;
    my $response = shift;

    return $response if ($response->has_error());

    if ($response->workflow()->{context}->{output}) {
        $response->result( $response->workflow()->{context}->{output} );
    } else {
        $response->error( 50003 );
    }

    return $response;

}

sub disconnect_backend {

    my $self = shift;

    return unless $self->has_backend;
    eval { $self->backend->disconnect if $self->backend };
}

sub mojo_req_from_cgi {
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

1;

__END__;
