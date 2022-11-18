package OpenXPKI::Client::Service::Base;
use Moose;


use Carp;
use English;
use Data::Dumper;
use Crypt::PKCS10;
use Log::Log4perl qw(:easy);
use MIME::Base64;
use Digest::SHA qw(sha1_hex);
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Service::Response;

with 'OpenXPKI::Client::Service::Role::PickupWorkflow';

has config => (
    is      => 'rw',
    isa     => 'Object',
    required => 1,
);

has backend => (
    is      => 'rw',
    isa     => 'Object|Undef',
    lazy => 1,
    predicate => 'has_backend',
    builder => '_init_backend',
);

has logger => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default  => sub { my $self = shift; return $self->config()->logger() },
);

has operation => (
    is      => 'ro',
    isa     => 'Str',
    #required => 1,
);

sub _init_backend {

    my $self = shift;
    my $config = $self->config();
    my $conf = $config->config();

    return OpenXPKI::Client::Simple->new({
        logger => $self->logger(),
        config => $conf->{global}, # realm and locale
        auth => $conf->{auth} || {}, # auth config
    });

}

sub build_params {

    my $self = shift;
    my $operation = shift;

    my $conf = $self->config()->config();

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
        $param->{'interface'} = $self->config()->service();
    }

    my %envkeys;
    if ($conf->{$operation}->{env}) {
        %envkeys = map {$_ => 1} (split /\s*,\s*/, $conf->{$operation}->{env});
        $self->logger->trace("Found env keys " . $conf->{$operation}->{env});
    } elsif ($operation =~ /enroll/) {
        %envkeys = ( signer_cert => 1 );
        $envkeys{'server'} = 1 unless ($servername);
    }

    # IP Transport
    if ($envkeys{'client_ip'}) {
        $param->{'client_ip'} = $ENV{REMOTE_ADDR};
    }

    # User Agent
    if ($envkeys{'user_agent'}) {
        $param->{'user_agent'} = $ENV{HTTP_USER_AGENT};
    }

    if ($envkeys{'endpoint'}) {
        $param->{'endpoint'} = $self->config()->endpoint();
    }

    # be lazy and use endpoint name as servername
    if ($envkeys{'server'}) {
        if ($servername) {
            $self->logger->error("ENV server and servername are both set but are mutually exclusive");
            return;
        }
        my $endpoint = $self->config()->endpoint();
        if (!$endpoint) {
            $self->logger->error("ENV server requested but endpoint is not set");
            return;
        }
        $param->{'server'} = $endpoint;
        $param->{'interface'} = $self->config()->service();
    }

    # Gather data from TLS session
    if ( defined $ENV{HTTPS} && lc( $ENV{HTTPS} ) eq 'on' ) {

        $self->logger->debug("calling context is https");
        my $auth_dn = $ENV{SSL_CLIENT_S_DN};
        my $auth_pem = $ENV{SSL_CLIENT_CERT};
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

    $self->logger->trace(sprintf('Extra params for %s: %s ', $operation, Dumper $param )) if ($self->logger->is_trace());

    return $param;

}

sub handle_enrollment_request {

    my $self = shift;
    my $cgi = shift;
    my $operation = shift || $self->operation();

    my $config = $self->config();
    my $log = $self->logger();

    my $conf = $config->config();

    # Build configuration parameters, can be overloaded by protocols
    # e.g. SCEP to inject data from the input
    my $param = $self->build_params( $operation, $cgi );

    if (!defined $param) {
        return OpenXPKI::Client::Service::Response->new( 50010 );
    }

    # create the client object
    my $client = $self->backend();
    if ( !$client ) {
        return OpenXPKI::Client::Service::Response->new( 50001 );
    }

    # if pkcs10 was not already passed from build params
    # we assume it is a raw POST
    if (!defined $param->{pkcs10}) {
        # Usually PEM encoded but without borders as POSTDATA
        my $pkcs10 = $cgi->param( 'POSTDATA' );
        if (!$pkcs10) {
            $log->debug( 'Incoming enrollment with empty body' );
            return OpenXPKI::Client::Service::Response->new( 40003 );
        }

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

    # fall back to simpleneroll config for simplereenroll if not set
    if ($operation eq 'simplereenroll' && !$conf->{simplereenroll}) {
        $operation = "simpleenroll";
    }

    my $pickup_config = {(
        workflow => 'certificate_enroll',
        pickup => 'pkcs10',
        pickup_attribute => 'transaction_id',
        ),
        %{$conf->{$operation} || {}},
    };
    $log->debug(Dumper $pickup_config);

    my $workflow;
    eval {

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
                my $val = $param->{$key} // $cgi->param($key);
                $pickup_value->{$key} = $val if (defined $val);
            }
        } else {
            # pickup via transaction_id
            $pickup_value = $param->{transaction_id};
        }

        # try pickup
        $workflow = $self->pickup_workflow($pickup_config, $pickup_value);

        # pickup return undef if no workflow was found - start new one
        if (!$workflow) {
            $log->debug(sprintf("Initialize %s with params %s",
                $pickup_config->{workflow}, join(", ", keys %{$param})));
            $workflow = $client->handle_workflow({
                type => $pickup_config->{workflow},
                params => $param,
            });
        }

        $log->trace( 'Workflow info '  . Dumper $workflow ) if ($log->is_trace());
    };

    if (!$workflow || ( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {
        if (my $err = $client->last_reply()->{ERROR}) {
            if ($err->{CLASS} eq 'OpenXPKI::Exception::InputValidator') {
                $log->info( 'Input validation failed' );
                return OpenXPKI::Client::Service::Response->new( 40004 );
            }
        }
        $log->error( $EVAL_ERROR ? $EVAL_ERROR : 'Internal Server Error');
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

    if ($workflow->{'proc_state'} ne 'finished') {
        my $retry_after = 300;
        if ($workflow->{'proc_state'} eq 'pause') {
            my $delay = $workflow->{'wake_up_at'} - time();
            $retry_after = ($delay > 30) ? $delay : 30;
        }

        $log->info('Request Pending - ' . $workflow->{'state'});
        return OpenXPKI::Client::Service::Response->new({
            retry_after => $retry_after,
            workflow => $workflow,
        });
    }

    $log->trace(Dumper $workflow->{context}) if ($log->is_trace);

    my $cert_identifier = $workflow->{context}->{cert_identifier};

    if (!$cert_identifier) {
        return OpenXPKI::Client::Service::Response->new({
            error => 40006,
            ($workflow->{context}->{error_code} ? (error_message => $workflow->{context}->{error_code}) : ()),
            workflow => $workflow,
        });
    }

    $log->debug( 'Sending output for ' . $cert_identifier);

    return $self->_prepare_result($workflow, $operation);

}

sub _prepare_result {

    my $self = shift;
    my $workflow = shift;
    # not used for the default case
    # my $operation = shift;

    my $result = $self->backend()->run_command('get_cert',{
        format => 'PKCS7',
        identifier => $workflow->{context}->{cert_identifier},
    });

    $result =~ s{-----(BEGIN|END) PKCS7-----}{}g;
    $result =~ s{\s}{}gxms;

    return OpenXPKI::Client::Service::Response->new({
        result => $result,
        workflow => $workflow,
    });

}

sub handle_property_request {

    my $self = shift;
    my $cgi = shift;
    my $operation = shift || $self->operation();

    my $config = $self->config();
    my $log = $self->logger();

    my $conf = $config->config();

    my $param = $self->build_params( $operation, $cgi );

    if (!defined $param) {
        return OpenXPKI::Client::Service::Response->new( 50010 );
    }

    # create the client object
    my $client = $self->backend();
    if ( !$client ) {
        return OpenXPKI::Client::Service::Response->new( 50001 );
    }

    # TODO - we need to consolidate the workflows for the different protocols
    my $workflow_type = $conf->{$operation}->{workflow} ||
        $self->config()->service().'_'.lc($operation);
    $log->debug( 'Start workflow type ' . $workflow_type );
    $log->trace( 'Workflow Paramters '  . Dumper $param );


    my $workflow = $client->handle_workflow({
        type => $workflow_type,
        params => $param
    });

    if (!$workflow || ( $workflow->{'proc_state'} ne 'finished' )) {
        if (my $err = $client->last_reply()->{ERROR}) {
            if ($err->{CLASS} eq 'OpenXPKI::Exception::InputValidator') {
                $log->info( 'Input validation failed' );
                return OpenXPKI::Client::Service::Response->new( 40004 );
            }
        }
        $log->error( $EVAL_ERROR ? $EVAL_ERROR : 'Internal Server Error' );
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

    $log->trace( 'Workflow info '  . Dumper $workflow );

    my $out = $workflow->{context}->{output};

    return OpenXPKI::Client::Service::Response->new( 50003 ) unless($out);

    # the workflows should return base64 encoded raw data
    # but the old EST GetCA workflow returned PKCS7 with PEM headers
    if ($workflow_type eq 'est_cacerts') {
        $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
        $out =~ s{\s}{}gxms;
    }

    return OpenXPKI::Client::Service::Response->new({
        result => $out,
        workflow => $workflow,
    });

}

sub terminate {

    my $self = shift;
    if ($self->has_backend()) {
        if (my $client = $self->backend()) {
            $client->disconnect();
        }
    }
}

__PACKAGE__->meta->make_immutable;

__END__;
