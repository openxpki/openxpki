package OpenXPKI::Client::Service::EST;
use OpenXPKI -class;

with qw(
    OpenXPKI::Client::Service::Role::Info
    OpenXPKI::Client::Service::Role::Base
);

# Core modules
use MIME::Base64;
use List::Util qw( any );
use Exporter qw( import );

# Project modules
use OpenXPKI::Crypt::X509;

# Symbols to export by default
# (we avoid Moose::Exporter's import magic because that switches on all warnings again)
our @EXPORT = qw( cgi_safe_sub ); # provided by OpenXPKI::Client::Service::Role::Base

# required by OpenXPKI::Client::Service::Role::Info
sub declare_routes ($r) {
    # EST urls look like
    #   /.well-known/est/cacerts
    #   /.well-known/est/namedservice/cacerts  # incl. endpoint
    # <endpoint> is optional because a default is given.
    $r->any('/.well-known/est/<endpoint>/<operation>')->to(
        service_class => __PACKAGE__,
        endpoint => 'default',
    );
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare ($self, $c) {
    $self->operation($c->stash('operation'));

    if ($self->request->is_secure) {
        # what we expect -> noop
    } elsif ($self->config->get('global.insecure')) {
        # RFC demands TLS for EST but we might have a SSL proxy in front
        $self->log->debug("EST request via insecure connection (plain HTTP) - allowed via configuration");
    } else {
        $self->log->error('EST request via insecure connection (plain HTTP)');
        die $self->new_response( 40300 );
    }

    $c->res->headers->content_type("application/pkcs7-mime; smime-type=certs-only"); # default
}

# required by OpenXPKI::Client::Service::Role::Base
sub send_response ($self, $c, $response) {
    $self->disconnect_backend;

    if ($response->has_error) {
        return $c->render(text => $response->error_message."\n");

    } elsif ($response->is_pending) {
        $c->res->headers->add('Retry-After' => $response->retry_after);
        return $c->render(text => $response->http_status_message."\n");

    } elsif (not $response->has_result) {
        # revoke returns a 204 no content on success
        return $c->rendered;

    } else {
        # Default is base64 encoding, but we can turn on binary
        my $is_binary = $self->config->get('output.encoding')//'' eq 'binary';
        my $data = $is_binary ? decode_base64($response->result) : $response->result;
        $c->res->headers->add('content-transfer-encoding' => ($is_binary ? 'binary' : 'base64'));
        $data =~ s/(.{1,64})/$1\n/g if ($self->config->get('output.wrap'));
        return $c->render(data => $data);
    }
}

# required by OpenXPKI::Client::Service::Role::Base
sub op_handlers {
    return [
        'cacerts' => sub ($self) {
            my $response = $self->handle_property_request;

            # FIXME Legacy: the workflows should return base64 encoded raw data
            # but the old EST GetCA workflow returned PKCS7 with PEM headers.
            my $out = $response->result || '';
            $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
            $out =~ s{\s}{}gxms;
            $response->result($out);
            return $response;
        },
        'csrattrs' => sub ($self) {
            $self->content_type("application/csrattrs"); # default
            return $self->handle_property_request;
        },
        ['simpleenroll', 'simplereenroll', 'simplerevoke'] => sub ($self) {
            # TODO this should be merged with the stuff in Base without having protocol specific items in the core code
            $self->add_wf_param(server => $self->endpoint) unless $self->default_wf_param('server');
            $self->add_wf_param(interface => $self->service_name);
            if (my $signer = $self->webserver_env->{SSL_CLIENT_CERT}) {
                $self->add_wf_param(signer_cert => $signer);
            }

            if ('simplerevoke' eq $self->operation) {
                $self->handle_revocation_request;
            } else {
                $self->set_pkcs10_and_tid(decode_base64($self->request->body));
                $self->handle_enrollment_request;
            }
        },
        # "serverkeygen" and "fullcmc" are not supported
        ['serverkeygen', 'fullcmc'] => sub ($self) {
            $self->log->error(sprintf('Operation "%s" not implemented', $self->operation));
            return $self->new_response( 50100 );
        },
    ];
}

# required by OpenXPKI::Client::Service::Role::Base
sub cgi_set_custom_wf_params ($self) {
    # TODO this should be merged with the stuff in Base without
    # having protocol specific items in the core code
    if (any { $self->operation eq $_ } qw( simpleenroll simplereenroll simplerevoke )) {
        $self->add_wf_param(server => $self->endpoint) unless $self->default_wf_param('server');
        $self->add_wf_param(interface => $self->service_name);
        if (my $signer = $self->webserver_env->{SSL_CLIENT_CERT}) {
            $self->add_wf_param(signer_cert => $signer);
        }
    }

    $self->set_pkcs10_and_tid(decode_base64($self->request->body)) if $self->is_enrollment;
}

# required by OpenXPKI::Client::Service::Role::Base
sub prepare_enrollment_result ($self, $workflow) {
    my $result = $self->client_simple->run_command('get_cert',{
        format => 'PKCS7',
        identifier => $workflow->{context}->{cert_identifier},
    });

    $result =~ s{-----(BEGIN|END) PKCS7-----}{}g;
    $result =~ s{\s}{}gxms;

    return $self->new_response(
        result => $result,
        workflow => $workflow,
    );
}

sub handle_revocation_request ($self) {
    my $param = { $self->wf_params->%* }; # copy hash

    # preset reason code if not already done from wrapper config
    $param->{reason_code} //= 'unspecified';

    my $body = $self->request->body
        or do {
            $self->log->debug( 'Incoming revocation request with empty body' );
            return $self->new_response( 40003 );
        };

    try {
        my $x509 = OpenXPKI::Crypt::X509->new( decode_base64($body) );
        $param->{certificate} = $x509->pem;
    } catch ($error) {
        return $self->new_response( 40002 );
    }

    my $workflow_type = $self->config->get('simplerevoke.workflow') || 'certificate_revoke';

    my $response = $self->new_response(
        workflow => $self->run_workflow(type => $workflow_type, params => $param)
    );

    if ($response->has_error) {
        # noop
    } elsif ($response->is_state('SUCCESS')) {
        $response->http_status_code(204);
    } elsif ($response->is_state('CANCELED')) {
        $response->http_status_code(409);
    } else {
        $response->http_status_code(400);
    }
    return $response;
}

__PACKAGE__->meta->make_immutable;

__END__;
