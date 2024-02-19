package OpenXPKI::Client::Service::Base;
use Moose::Role;

with 'OpenXPKI::Client::Service::Role::PickupWorkflow';

requires 'service_name';
requires 'custom_wf_params';
requires 'prepare_enrollment_result';

# Core modules
use Carp;
use English;
use Data::Dumper;
use MIME::Base64;
use Digest::SHA qw(sha1_hex);

# CPAN modules
use Crypt::PKCS10;
use Log::Log4perl qw(:easy);
use Feature::Compat::Try;
use Mojo::Message::Request;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Service::Response;


has config_obj => (
    is => 'rw',
    isa => 'OpenXPKI::Client::Config',
    required => 1,
);

has endpoint => (
    is => 'ro',
    isa => 'Str',
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

# the endpoint config
has config => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    default => sub { $_[0]->config_obj->endpoint_config($_[0]->endpoint) },
);

has logger => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    init_arg => undef,
    default => sub { $_[0]->config_obj->logger },
);

has request => (
    is => 'ro',
    isa => 'Mojo::Message::Request',
    required => 1,
);

has backend => (
    is => 'rw',
    isa => 'Object|Undef',
    lazy => 1,
    predicate => 'has_backend',
    builder => '_init_backend',
);

# 'operation' might be set late
has operation => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { die "Attempt to access attribute 'operation' before it was set" },
);

# Workflow parameters. A value of "undef" indicates an error.
has wf_params => (
    is => 'ro',
    isa => 'HashRef|Undef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_wf_params',
);


sub _init_backend {

    my $self = shift;

    return OpenXPKI::Client::Simple->new({
        logger => $self->logger(),
        config => $self->config->{global}, # realm and locale
        auth => $self->config->{auth} || {}, # auth config
    });

}

# Workflow parameters. A value of "undef" indicates an error.
sub _build_wf_params {

    my $self = shift;

    my $operation = $self->operation;
    my $conf = $self->config;
    my $param = {};

    # look for preset params
    foreach my $key (keys %{$conf->{$operation}}) {
        next unless ($key =~ m{preset_(\w+)});
        $param->{$1} = $conf->{$operation}->{$key};
    }

    my $servername = $conf->{$operation}->{servername} || $conf->{global}->{servername};
    # if given, append to the paramter list
    if ($servername) {
        $param->{'server'} = $servername;
        $param->{'interface'} = $self->service_name;
    }

    my %envkeys;
    if ($conf->{$operation}->{env}) {
        %envkeys = map {$_ => 1} (split /\s*,\s*/, $conf->{$operation}->{env});
        $self->logger->trace("Found env keys: " . $conf->{$operation}->{env});
    }

    # IP Transport
    if ($envkeys{'client_ip'}) {
        $param->{'client_ip'} = $self->remote_address;
    }

    # User Agent
    if ($envkeys{'user_agent'}) {
        $param->{'user_agent'} = $self->request->headers->user_agent;
    }

    if ($envkeys{'endpoint'}) {
        $param->{'endpoint'} = $self->endpoint;
    }

    # be lazy and use endpoint name as servername
    if ($envkeys{'server'}) {
        if ($servername) {
            $self->logger->error("ENV server and servername are both set but are mutually exclusive");
            return;
        }
        my $endpoint = $self->endpoint;
        if (!$endpoint) {
            $self->logger->error("ENV server requested but endpoint is not set");
            return;
        }
        $param->{'server'} = $endpoint;
        $param->{'interface'} = $self->service_name;
    }

    # Gather data from TLS session
    if ( $self->request->is_secure ) {

        $self->logger->debug("calling context is https");
        my $auth_dn = $self->apache_env->{SSL_CLIENT_S_DN};
        my $auth_pem = $self->apache_env->{SSL_CLIENT_CERT};
        if ( defined $auth_dn ) {
            $self->logger->info("authenticated client DN: $auth_dn");
            if ($envkeys{'signer_dn'}) {
                $param->{'signer_dn'} = $auth_dn;
            }
            if ($auth_pem && $envkeys{'signer_cert'}) {
                $param->{'signer_cert'} = $auth_pem;
            }
        } else {
            $self->logger->debug("unauthenticated (no cert)");
        }
    }

    # hook that allows consuming classes to add own parameters
    $self->custom_wf_params($param);

    $self->logger->trace(sprintf("Extra params for operation '%s': %s", $self->operation, Dumper $param)) if $self->logger->is_trace;

    return $param;
}

sub build_pickup_config {

    my $self = shift;
    my $param = shift;

    my $conf = $self->config;
    my $pickup_config = {(
        workflow => 'certificate_enroll',
        pickup => 'pkcs10',
        pickup_attribute => 'transaction_id',
        ),
        %{$conf->{$self->operation()} || {}},
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


sub handle_enrollment_request {

    my $self = shift;

    die "Passing operation to handle_enrollment_request is no longer supported." if (@_);

    my $log = $self->logger();

    # Build configuration parameters, can be overloaded by protocols,
    # e.g. for SCEP to inject data from the input
    my $param = $self->wf_params
        or return OpenXPKI::Client::Service::Response->new( 50010 );

    # create the client object
    my $client = $self->backend
        or return OpenXPKI::Client::Service::Response->new( 50001 );

    # if pkcs10 was not already passed from build params
    # we assume it is a raw POST
    if (!defined $param->{pkcs10}) {
        # Usually PEM encoded but without borders as POSTDATA
        my $pkcs10 = $self->request->body
            or do {
                $log->debug( 'Incoming enrollment with empty body' );
                return OpenXPKI::Client::Service::Response->new( 40003 );
            };

        # Crypt::PKCS10 expects binary or PEM with headers
        # for simplecmc the payload is already binary -> noop
        # for EST the payload is base64 encoded -> decode
        # Sending PEM with headers is not allowed in neither one but
        # will be gracefully accepted and converted by Crypt::PKSC10
        if ($pkcs10 =~ m{\A [\w/+=\s]+ \z}xm) {
            $pkcs10 = decode_base64($pkcs10);
        }

        Crypt::PKCS10->setAPIversion(1);
        my $decoded = Crypt::PKCS10->new($pkcs10, ignoreNonBase64 => 1, verifySignature => 1);
        if (!$decoded) {
            $log->error('Unable to parse PKCS10: '. Crypt::PKCS10->error);
            $log->debug($pkcs10);
            return OpenXPKI::Client::Service::Response->new( 40002 );
        }
        $param->{pkcs10} = $decoded->csrRequest(1);
        # we might accept transaction_id via GET with POSTed payload
        $param->{transaction_id} = sha1_hex($decoded->csrRequest) unless($param->{transaction_id});
    }

    my ($pickup_config, $pickup_value) = $self->build_pickup_config( $param );
    $log->trace(Dumper $pickup_config) if $log->is_trace;

    my $workflow;

    try {
        # try pickup
        $workflow = $self->pickup_workflow($pickup_config, $pickup_value);

        # it was a pickup, it was not successful, we do not have a PKCS10
        if ($pickup_value && !$workflow && !$param->{pkcs10}) {
            $log->debug("Pickup failed and no PKCS10 given");
            return OpenXPKI::Client::Service::Response->new( 40005 );
        }

        # pickup return undef if no workflow was found - start new one
        if (!$workflow) {
            $log->debug(sprintf("Initialize %s with params %s",
                $pickup_config->{workflow}, join(", ", keys %{$param})));

            $workflow = $client->handle_workflow({
                type => $pickup_config->{workflow},
                params => $param,
            });
        }

        $log->trace( 'Workflow info '  . Dumper $workflow ) if $log->is_trace;
    }
    catch ($error) {
        $log->error( $error );
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

    if (!$workflow || ( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {
        my $reply = $client->last_reply() || {};
        if (my $err = $reply->{ERROR}) {
            if ($err->{CLASS} eq 'OpenXPKI::Exception::InputValidator') {
                $log->info( 'Input validation failed' );
                return OpenXPKI::Client::Service::Response->new( 40004 );
            }
        }
        $log->error( 'Internal server error');
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

    if ($workflow->{'proc_state'} ne 'finished') {
        my $retry_after = 300;
        if ($workflow->{'proc_state'} eq 'pause') {
            my $delay = $workflow->{'wake_up_at'} - time();
            $retry_after = ($delay > 30) ? $delay : 30;
        }

        $log->info('Request Pending - ' . $workflow->{'state'});
        return OpenXPKI::Client::Service::Response->new(
            retry_after => $retry_after,
            workflow => $workflow,
        );
    }

    $log->trace(Dumper $workflow->{context}) if $log->is_trace;

    my $cert_identifier = $workflow->{context}->{cert_identifier};

    if (!$cert_identifier) {
        return OpenXPKI::Client::Service::Response->new(
            error => 40006,
            ($workflow->{context}->{error_code} ? (error_message => $workflow->{context}->{error_code}) : ()),
            workflow => $workflow,
        );
    }

    $log->debug( 'Sending output for ' . $cert_identifier);

    return $self->prepare_enrollment_result($workflow);

}

sub handle_property_request {

    my $self = shift;

    die "Passing operation to handle_property_request is no longer supported." if (@_);

    my $operation = $self->operation;
    my $log = $self->logger;

    my $param = $self->wf_params
        or return OpenXPKI::Client::Service::Response->new( 50010 );

    # TODO - we need to consolidate the workflows for the different protocols
    my $workflow_type = $self->config->{$operation}->{workflow} ||
        $self->service_name.'_'.lc($operation);
    $log->debug( 'Start workflow type ' . $workflow_type );
    $log->trace( 'Workflow Paramters '  . Dumper $param );

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

    my $log = $self->logger();
    $log->trace( 'Workflow info '  . Dumper $workflow );

    if (!$workflow || ( $workflow->{'proc_state'} !~ m{finished|manual} )) {
        if (my $err = $client->last_reply()->{ERROR}) {
            if ($err->{CLASS} eq 'OpenXPKI::Exception::InputValidator') {
                $log->info( 'Input validation failed' );
                return OpenXPKI::Client::Service::Response->new( 40004 );
            }
        }
        $log->error( $EVAL_ERROR ? $EVAL_ERROR : 'Internal Server Error' );
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

sub terminate {

    my $self = shift;
    if ($self->has_backend()) {
        if (my $client = $self->backend()) {
            $client->disconnect();
        }
    }
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
