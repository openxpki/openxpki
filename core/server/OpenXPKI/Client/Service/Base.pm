package OpenXPKI::Client::Service::Base;

use Moose;
use warnings;
use strict;
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
    builder => '_init_backend',
);

has logger => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default  => sub { my $self = shift; return $self->config()->logger() },
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
    my $operation = shift;

    my $config = $self->config();
    my $log = $self->logger();

    my $conf = $config->config();

    my $param = $self->build_params( $operation );

    if (!defined $param) {
        return OpenXPKI::Client::Service::Response->new( 50010 );
    }

    # create the client object
    my $client = $self->backend();
    if ( !$client ) {
        return OpenXPKI::Client::Service::Response->new( 50001 );
    }

    # The CSR comes PEM encoded without borders as POSTDATA
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

    my $transaction_id = sha1_hex($decoded->csrRequest);

    my $workflow;
    eval {

        $param->{pkcs10} = $decoded->csrRequest(1);
        Log::Log4perl::MDC->put('tid', $transaction_id);
        $param->{transaction_id} = $transaction_id;

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
            $pickup_value = $transaction_id;
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
        $log->error( $EVAL_ERROR ? $EVAL_ERROR : 'Internal Server Error');
        $client->disconnect();
        return OpenXPKI::Client::Service::Response->new( 50003 );
    }

    if ($workflow->{'proc_state'} ne 'finished') {

        # the workflow might have another idea to calculate the transaction_id
        # so if its set in the result we overwrite the initial sha1 hash
        if ($workflow->{context}->{transaction_id}) {
            $transaction_id = $workflow->{context}->{transaction_id};
        }

        my $retry_after = 300;
        if ($workflow->{'proc_state'} eq 'pause') {
            my $delay = $workflow->{'wake_up_at'} - time();
            $retry_after = ($delay > 30) ? $delay : 30;
        }

        $log->info('Request Pending - ' . $workflow->{'state'});
        $client->disconnect();
        return OpenXPKI::Client::Service::Response->new({
            retry_after => $retry_after,
            workflow => $workflow,
        });
    }

    $log->trace(Dumper $workflow->{context}) if ($log->is_trace);

    my $cert_identifier = $workflow->{context}->{cert_identifier};

    if (!$cert_identifier) {
        $client->disconnect();
        return OpenXPKI::Client::Service::Response->new({
            error => 40006,
            ($workflow->{context}->{error_code} ? (error_message => $workflow->{context}->{error_code}) : ()),
            workflow => $workflow,
        });
    }

    my $result = $client->run_command('get_cert',{
        format => 'PKCS7',
        identifier => $cert_identifier,
    });
    $client->disconnect();

    $log->debug( 'Sending cert ' . $cert_identifier);

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
    my $operation = shift;

    my $config = $self->config();
    my $log = $self->logger();

    my $conf = $config->config();

    my $param = $self->build_params( $operation );

    if (!defined $param) {
        return OpenXPKI::Client::Service::Response->new( 50010 );
    }

    # create the client object
    my $client = $self->backend();
    if ( !$client ) {
        return OpenXPKI::Client::Service::Response->new( 50001 );
    }

    # TODO - we need to consolidate the workflows for the different protocols
    my $workflow = $client->handle_workflow({
        type => $conf->{$operation}->{workflow} || 'est_'.$operation,
        params => $param
    });

    $client->disconnect();

    $log->trace( 'Workflow info '  . Dumper $workflow );

    my $out = $workflow->{context}->{output};

    return OpenXPKI::Client::Service::Response->new( 50003 ) unless($out);

    # the workflows should return base64 encoded raw data
    # but the old workflows returned PKCS7 with PEM headers
    $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
    $out =~ s{\s}{}gxms;

    return OpenXPKI::Client::Service::Response->new({
        result => $out,
        workflow => $workflow,
    });

}

1;

__END__;
