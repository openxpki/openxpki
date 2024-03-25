package OpenXPKI::Client::Service::EST;
use OpenXPKI qw( -class -nonmoose );

extends 'Mojolicious::Controller';
with 'OpenXPKI::Client::Service::Base';

sub service_name { 'est' } # required by OpenXPKI::Client::Service::Base

# Core modules
use MIME::Base64;

# Project modules
use OpenXPKI::Crypt::X509;
use OpenXPKI::Client::Service::Response;


# Mojolicious entry point
sub index ($self) {
    if ($self->req->is_secure) {
        # what we expect -> noop
    } elsif ($self->config->{global}->{insecure}) {
        # RFC demands TLS for EST but we might have a SSL proxy in front
        $self->log->debug("Unauthenticated (plain http)");
    } else {
        $self->log->error('EST request via insecure connection');
        return $self->render(text => "HTTPS required\n", status => 403);
    }

    $self->res->headers->content_type("application/pkcs7-mime; smime-type=certs-only"); # default

    my $response = $self->handle_request;

    $self->disconnect_backend;

    # HTTP header
    if ($self->config->{output}->{headers}) {
        $self->res->headers->add($_ => $response->extra_headers->{$_}) for keys $response->extra_headers->%*;
    }

    if ($response->has_error) {
        return $self->render(text => $response->error_message."\n");

    } elsif ($response->is_pending) {
        $self->res->headers->add('-retry-after' => $response->retry_after);
        return $self->render(text => $response->http_status_message."\n");

    } elsif (not $response->has_result) {
        # revoke returns a 204 no content on success
        return $self->rendered;

    } else {
        # Default is base64 encoding, but we can turn on binary
        my $is_binary = $self->config->{output}->{encoding}//'' eq 'binary';
        my $data = $is_binary ? decode_base64($response->result) : $response->result;
        $self->res->headers->add('content-transfer-encoding' => ($is_binary ? 'binary' : 'base64'));
        return $self->render(data => $data);
    }
}

# required by OpenXPKI::Client::Service::Base
sub custom_wf_params ($self, $params) {
    # TODO this should be merged with the stuff in Base without
    # having protocol specific items in the core code
    if ($self->operation =~ m{simple((re)?enroll|revoke)}) {
        $params->{server} = $self->endpoint;
        $params->{interface} = $self->service_name;
        if (my $signer = $self->apache_env->{SSL_CLIENT_CERT}) {
            $params->{signer_cert} = $signer;
        }
    }

    $self->set_pkcs10_and_tid($params, decode_base64($self->request->body)) if $self->is_enrollment;

    return 1;
}

sub op_handlers {
    return [
        'cacerts' => sub {
            my $self = shift;
            my $response = $self->handle_property_request;

            # FIXME Legacy: the workflows should return base64 encoded raw data
            # but the old EST GetCA workflow returned PKCS7 with PEM headers.
            my $out = $response->result || '';
            $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
            $out =~ s{\s}{}gxms;
            $response->result($out);
            return $response;
        },
        'csrattrs' => sub {
            my $self = shift;
            $self->res->headers->content_type("application/csrattrs"); # default
            return $self->handle_property_request;
        },
        'simplerevoke' => \&handle_revocation_request,
        ['simpleenroll', 'simplereenroll'] => \&handle_enrollment_request,
        # "serverkeygen" and "fullcmc" are not supported
        ['serverkeygen', 'fullcmc'] => sub {
            my $self = shift;
            my $operation = shift;
            $self->log->error("Operation '$operation' not implemented");
            return OpenXPKI::Client::Service::Response->new( 50100 );
        },
    ];
}


# required by OpenXPKI::Client::Service::Base
sub prepare_enrollment_result ($self, $workflow) {
    my $result = $self->backend()->run_command('get_cert',{
        format => 'PKCS7',
        identifier => $workflow->{context}->{cert_identifier},
    });

    $result =~ s{-----(BEGIN|END) PKCS7-----}{}g;
    $result =~ s{\s}{}gxms;

    return OpenXPKI::Client::Service::Response->new(
        result => $result,
        workflow => $workflow,
    );
}

sub handle_revocation_request ($self) {
    my $param = $self->wf_params
        or return OpenXPKI::Client::Service::Response->new( 50010 );

    # preset reason code if not already done from wrapper config
    $param->{reason_code} = 'unspecified' unless defined $param->{reason_code};

    my $body = $self->request->body
        or do {
            $self->log->debug( 'Incoming revocation request with empty body' );
            return OpenXPKI::Client::Service::Response->new( 40003 );
        };

    try {
        my $x509 = OpenXPKI::Crypt::X509->new( decode_base64($body) );
        $param->{certificate} = $x509->pem;
    } catch ($error) {
        return OpenXPKI::Client::Service::Response->new( 40002 );
    }

    my $workflow_type = $self->config->{simplerevoke}->{workflow} || 'certificate_revoke';
    $self->log->debug( 'Start workflow type ' . $workflow_type );
    $self->log->trace( 'Workflow Paramters '  . Dumper $param ) if $self->log->is_trace;

    my $response = $self->run_workflow($workflow_type, $param);

    if ($response->has_error) {
        # noop
    } elsif ($response->state eq 'SUCCESS') {
        $response->http_status_code(204);
    } elsif ($response->state eq 'CANCELED') {
        $response->http_status_code(409);
    } else {
        $response->http_status_code(400);
    }
    return $response;
}

__PACKAGE__->meta->make_immutable;

__END__;
