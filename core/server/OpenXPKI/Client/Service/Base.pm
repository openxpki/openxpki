package OpenXPKI::Client::Service::Base;
use Moose::Role;

with 'OpenXPKI::Client::Service::Role::PickupWorkflow';

requires 'service_name';
requires 'custom_wf_params';
requires 'prepare_enrollment_result';
requires 'op_handlers';

# FIXME enable after phasing out fcgi scripts:
#requires 'tx';
#requires 'stash';
#requires 'log';
#requires 'oxi_config';

# Core modules
use Carp;
use English;
use Data::Dumper;
use MIME::Base64;
use Digest::SHA qw( sha1_hex );
use List::Util qw( first );

# CPAN modules
use Crypt::PKCS10;
use Log::Log4perl qw( :easy );
use Mojo::Message::Request;
use Moose::Exporter;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Log4perl::MojoLogger;

# Feature::Compat::Try should be done last to safely disable warnings
use Feature::Compat::Try;
# should be done after imports to safely disable warnings in Perl < 5.36
use experimental 'signatures';


Moose::Exporter->setup_import_methods(
    as_is => [ 'fcgi_safe_sub' ],
);


has config_obj => (
    is => 'rw',
    isa => 'OpenXPKI::Client::Config',
    lazy => 1,
    builder => '_build_config_obj',
);
sub _build_config_obj ($self) { $self->oxi_config($self->service_name) }

has endpoint => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '_build_endpoint',
);
sub _build_endpoint ($self) { $self->stash('endpoint') }

has apache_env => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_apache_env',
);
sub _build_apache_env ($self) { $self->stash('apache_env') }

has remote_address => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '_build_remote_address',
);
sub _build_remote_address ($self) { $self->tx->remote_address }

# the endpoint config
has config => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_config',
);
sub _build_config ($self) { $self->config_obj->endpoint_config($self->endpoint) }

has request => (
    is => 'ro',
    isa => 'Mojo::Message::Request',
    builder => '_build_request',
);
sub _build_request ($self) { $self->tx->req }

has backend => (
    is => 'rw',
    isa => 'Object|Undef',
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

# 'operation' may be overwritten later on
has operation => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    builder => '_build_operation',
);
sub _build_operation ($self) { $self->stash('operation') }

# Workflow parameters. A value of "undef" indicates an error.
has wf_params => (
    is => 'ro',
    isa => 'HashRef|Undef',
    lazy => 1,
    init_arg => undef,
    builder => '_build_wf_params',
);

has is_enrollment => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    default => 0,
);

# Workflow parameters. A value of "undef" indicates an error.
sub _build_wf_params {

    my $self = shift;

    my $p = {};

    try {
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
    }
    catch ($err) {
        if ($err->isa('OpenXPKI::Client::Service::Response')) {
            die $err;
        } else {
            die OpenXPKI::Client::Service::Response->new(
                error => 50010,
                error_message => "$err", # stringification
            );
        }
    }

    $self->log->trace(sprintf("Extra params for operation '%s': %s", $self->operation, Dumper $p)) if $self->log->is_trace;

    return $p;
}

# Fallback BUILD method: the service classes usually extend "Mojolicious::Controller"
# which is not a Moose object and thus does not inherit a BUILD method.
# "it's completely acceptable to apply a method modifier to BUILD in a role;
# you can even provide an empty BUILD subroutine in a role so the role is applicable
# even to classes without their own BUILD.
# https://metacpan.org/dist/Moose/view/lib/Moose/Manual/Construction.pod#BUILD-and-parent-classes
sub BUILD {}
after 'BUILD' => sub {
    my $self = shift;

    $self->config_obj->init_log4perl;

    my $log_category = 'client.' . $self->service_name;
    # We support two use cases:
    # 1) new style: consuming class is instantiated by OpenXPKI::Client::Web (Mojolicious)
    #    and owns a log() method via Mojolicious' DefaultHelpers
    try {
        $self->log->category($log_category);
    }
    # 2) legacy: parent class does not have a log() method/attribute, so we add one
    catch ($err) {
        $self->meta->make_mutable;
        $self->meta->add_attribute(
            log => (
                is => 'rw',
                isa => 'OpenXPKI::Log4perl::MojoLogger',
            )
        );
        $self->meta->make_immutable(inline_constructor => ($self->isa('Mojolicious::Controller') ? 0 : 1));
        $self->log(OpenXPKI::Log4perl::MojoLogger->new(category => $log_category));
    }

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
            $response = OpenXPKI::Client::Service::Response->new(
                error => 50000,
                error_message => "$err", # stringification
            );
        }
    }

    return $response;
}

sub handle_request {

    my $self = shift;

    $self->log->debug(sprintf("Incoming %s request '%s' on endpoint '%s'", uc($self->service_name), $self->operation, $self->endpoint)) if $self->log->is_debug;

    my $response;
    try {
        my $op_handlers = $self->op_handlers;

        die sprintf('%s->op_handlers() did not return an ArrayRef', $self->meta->name)
          unless ($op_handlers and ref $op_handlers eq 'ARRAY');

        my $i = 0;
        while (my $ops = $op_handlers->[$i++]) {
            $ops = ref $ops eq 'ARRAY' ? $ops : [ $ops ];
            my $handler = $op_handlers->[$i++]
              or die sprintf('Missing handler for operation [%s] in %s->op_handlers()', join(',', $ops->@*), $self->meta->name);

            if (my $op = first { $_ eq $self->operation } $ops->@*) {
                $response = $handler->($self, $op);

                # if ($ep_config->{output}->{headers}) {
                #     $self->res->headers->add($_ => $response->extra_headers->{$_}) for keys $response->extra_headers->%*;
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

    # TODO -- needs to be overwritten in CertEP - it always returns 200
    $self->res->code($response->http_status_code);
    $self->res->message($response->http_status_message);

    return $response;
}

sub handle_enrollment_request {

    my $self = shift;

    $self->is_enrollment(1);

    # Build configuration parameters, can be overloaded by protocols,
    # e.g. for SCEP to inject data from the input
    my $param = $self->wf_params
        or return OpenXPKI::Client::Service::Response->new( 50010 );

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
            $self->log->debug(sprintf("Initialize %s with params %s",
                $pickup_config->{workflow}, join(", ", keys %{$param})));

            $workflow = $client->handle_workflow({
                type => $pickup_config->{workflow},
                params => $param,
            });
        }

        $self->log->trace( 'Workflow info '  . Dumper $workflow ) if $self->log->is_trace;
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

    return $self->prepare_enrollment_result($workflow);

}

sub handle_property_request {

    my $self = shift;

    my $operation = $self->operation;

    my $param = $self->wf_params
        or return OpenXPKI::Client::Service::Response->new( 50010 );

    # TODO - we need to consolidate the workflows for the different protocols
    my $workflow_type = $self->config->{$operation}->{workflow} ||
        $self->service_name.'_'.lc($operation);
    $self->log->debug( 'Start workflow type ' . $workflow_type );
    $self->log->trace( 'Workflow Paramters '  . Dumper $param ) if $self->log->is_trace;

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

    $self->log->trace( 'Workflow info '  . Dumper $workflow ) if $self->log->is_trace;

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
