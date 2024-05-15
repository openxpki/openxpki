#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Fast;
use Data::Dumper;
use English;

use Mojo::Message::Request;

use OpenXPKI::Client::Config;
use OpenXPKI::Client::Service::EST;

my $config = OpenXPKI::Client::Config->new('est');
my $log = $config->logger();
$log->info("EST handler initialized");

while (my $cgi = CGI::Fast->new("")) {

    my $req = OpenXPKI::Client::Service::EST->cgi_to_mojo_request;

    # EST urls look like
    # /.well-known/est/cacerts
    # or with a label /.well-known/est/namedservice/cacerts
    # Supported operations are
    # cacerts, simpleenroll, simplereenroll, , csrattrs
    # serverkeygen and fullcmc is not supported
    my ($endpoint, $operation) = $config->parse_uri;
    my $ep_config = $config->endpoint_config($endpoint);

    if ($operation !~ m{(cacerts|simpleenroll|simplereenroll|csrattrs|simplerevoke)}) {
        print $cgi->header( -status => '501 Not implemented', -type => 'text/plain');
        print "Method not implemented\n";
        $log->error('Method not implemented');
        next;
    }

    $log->trace(sprintf("Incoming EST request '%s' on endpoint '%s'", $operation, $endpoint));

    if ( lc( $ENV{HTTPS} // '' ) eq 'on') {
        # what we expect -> noop
    } elsif ($ep_config->{global}->{insecure}) {
        # RFC demands TLS for EST but we might have a SSL proxy in front
        $log->debug("unauthenticated (plain http)");

    }  else {
        print $cgi->header( -status => '403 Forbidden', -type => 'text/plain', 'charset' => 'utf8');
        print "HTTPS required\n";
        $log->error('EST request via insecure connection');
        next;
    }

    # TODO - this should be removed
    if ($operation eq 'simplereenroll'
        and not $ep_config->{'simplereenroll'}
        and $ep_config->{'simpleenroll'}
    ) {
        $operation = 'simpleenroll';
        $log->warn("Fall back to 'simpleenroll' configuration on 'simplereenroll'");
    }

    my $client = OpenXPKI::Client::Service::EST->new(
        service_name => 'est',
        config_obj => $config,
        apache_env => \%ENV,
        remote_address => $ENV{REMOTE_ADDR},
        request => $req,
        endpoint => $endpoint,
        operation => $operation,
    );

    my $mime = "application/pkcs7-mime; smime-type=certs-only";

    my $response = cgi_safe_sub $client, sub {
        if ($operation eq 'cacerts') {
            my $r = $client->handle_property_request;

            # the workflows should return base64 encoded raw data
            # but the old EST GetCA workflow returned PKCS7 with PEM headers
            my $out = $r->result || '';
            $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
            $out =~ s{\s}{}gxms;
            $r->result($out);
            return $r;

        } elsif($operation eq 'csrattrs') {
            $mime = "application/csrattrs";
            return $client->handle_property_request;

        } elsif($operation eq 'simplerevoke') {
            return $client->handle_revocation_request;

        } else {
            return $client->handle_enrollment_request;
        }
    };

    $log->debug('Status: ' . $response->http_status_line);
    $log->trace(Dumper $response) if $log->is_trace;
    $log->error($response->error_message) if $response->has_error;

    $client->disconnect_backend;

    $response->add_debug_headers if $client->config->{output}->{headers};
    my @extra_header = %{ $client->cgi_headers($response->extra_headers) };

    if ($response->has_error()) {
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            -charset => 'utf8',
            @extra_header
        );
        print $response->error_message()."\n";

    } elsif ($response->is_pending()) {

        my $transaction_id = $response->transaction_id();
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            -charset => 'utf8',
            -retry_after => $response->retry_after(),
            @extra_header
        );
        print "202 Request Pending - Retry Later ($transaction_id)\n";

    # revoke returns a 204 no content on success
    } elsif (!$response->has_result) {

        print $cgi->header(
            -status => $response->http_status_line(),
            @extra_header
        );

    } else {

        # Default is base64 encoding, but we can turn on binary
        my $encoding = $ep_config->{output}->{encoding} || 'base64';
        my $out = $response->result;
        if ($encoding eq 'binary') {
            $out = decode_base64($out);
        } else {
            $encoding = 'base64';
        }
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => $mime,
            -content_length => length $out,
            -content_transfer_encoding => $encoding,
            -charset => '',
            @extra_header
        );
        print $out;
    }

}
