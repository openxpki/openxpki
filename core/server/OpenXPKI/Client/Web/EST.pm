package OpenXPKI::Client::Web::EST;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# Core modules
use Data::Dumper;
use List::Util qw( none );

# Project modules
use OpenXPKI::Client::Config;
use OpenXPKI::Client::Service::EST;


sub index ($self) {
    my $endpoint = $self->stash('endpoint');
    my $operation = $self->stash('operation');
    $operation =~ s/\.exe$//i;

    Log::Log4perl::MDC->put('endpoint', $endpoint);

    my $config = $self->oxi_config('est');
    my $ep_config = $config->endpoint_config($endpoint);

    # "serverkeygen" and "fullcmc" are not supported
    if (none { $operation eq $_ } qw( cacerts simpleenroll simplereenroll csrattrs simplerevoke )) {
        $self->log->error("Method not '$operation' implemented");
        return $self->render(text => "Method not implemented\n", status => 501);
    }

    $self->log->trace(sprintf("Incoming EST request '%s' on endpoint '%s'", $operation, $endpoint));

    if ($self->req->is_secure) {
        # what we expect -> noop
    } elsif ($ep_config->{global}->{insecure}) {
        # RFC demands TLS for EST but we might have a SSL proxy in front
        $self->log->debug("Unauthenticated (plain http)");
    } else {
        $self->log->error('EST request via insecure connection');
        return $self->render(text => "HTTPS required\n", status => 403);
    }

    my $client = OpenXPKI::Client::Service::EST->new(
        config_obj => $config,
        apache_env => $self->stash('apache_env'),
        remote_address => $self->tx->remote_address,
        request => $self->tx->req,
        endpoint => $endpoint,
        operation => $operation,
    );

    $self->res->headers->content_type("application/pkcs7-mime; smime-type=certs-only"); # default

    my $response;
    if ('cacerts' eq $operation) {
        $response = $client->handle_property_request;

        # the workflows should return base64 encoded raw data
        # but the old EST GetCA workflow returned PKCS7 with PEM headers
        my $out = $response->result || '';
        $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
        $out =~ s{\s}{}gxms;
        $response->result($out);

    } elsif ('csrattrs' eq $operation) {
        $self->res->headers->content_type("application/csrattrs"); # default
        $response = $client->handle_property_request;

    } elsif ('simplerevoke' eq $operation) {
        $response = $client->handle_revocation_request;

    } else {
        $response = $client->handle_enrollment_request;
    }

    $self->log->debug('Status: ' . $response->http_status_line);
    $self->log->trace(Dumper $response) if !$self->log->can('is_trace') || $self->log->is_trace;

    # close backend connection
    $client->terminate;

    # HTTP header
    $self->res->code($response->http_status_code);
    $self->res->message($response->http_status_message);
    if ($ep_config->{output}->{headers}) {
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
        my $is_binary = $ep_config->{output}->{encoding}//'' eq 'binary';
        my $data = $is_binary ? decode_base64($response->result) : $response->result;
        $self->res->headers->add('content-transfer-encoding' => ($is_binary ? 'binary' : 'base64'));
        return $self->render(data => $data);
    }
}

1;
