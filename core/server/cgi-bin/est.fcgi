#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Fast;
use Data::Dumper;
use English;

use OpenXPKI::Client::Config;
use OpenXPKI::Client::Service::Base;

my $config = OpenXPKI::Client::Config->new('est');
my $log = $config->logger();
$log->info("EST handler initialized");

while (my $cgi = CGI::Fast->new()) {

    # EST urls look like
    # /.well-known/est/cacerts
    # or with a label /.well-known/est/namedservice/cacerts
    # Supported operations are
    # cacerts, simpleenroll, simplereenroll, , csrattrs
    # serverkeygen and fullcmc is not supported
    $config->parse_uri();
    my $operation = $config->route();
    if ($operation !~ m{(cacerts|simpleenroll|simplereenroll|csrattrs)}) {
        print $cgi->header( -status => '501 Not implemented', -type => 'text/plain');
        print "Method not implemented\n";
        $log->error('Method not implemented');
        next;
    }

    $log->trace(sprintf("Incoming EST request %s on endpoint %s", $operation, $config->endpoint()));

    if ( lc( $ENV{HTTPS} // '' ) eq 'on') {
        # what we expect -> noop
    } elsif ($config->config()->{global}->{insecure}) {
        # RFC demands TLS for EST but we might have a SSL proxy in front
        $log->debug("unauthenticated (plain http)");

    }  else {
        print $cgi->header( -status => '403 Forbidden', -type => 'text/plain', 'charset' => 'utf8');
        print "HTTPS required\n";
        $log->error('EST request via insecure connection');
        next;
    }

    my $client = OpenXPKI::Client::Service::Base->new(
        config => $config,
        logger => $log,
        operation => $operation,
    );

    my $response;
    my $mime = "application/pkcs7-mime; smime-type=certs-only";
    if ($operation eq 'cacerts') {
        $response = $client->handle_property_request($cgi);

        # the workflows should return base64 encoded raw data
        # but the old EST GetCA workflow returned PKCS7 with PEM headers
        my $out = $response->result || '';
        $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
        $out =~ s{\s}{}gxms;
        $response->result($out);

    } elsif($operation eq 'csrattrs') {
        $mime = "application/csrattrs";
        $response = $client->handle_property_request($cgi);
    } else {
        $response = $client->handle_enrollment_request($cgi);
    }

    $log->debug('Status: ' . $response->http_status_line());
    $log->trace(Dumper $response) if ($log->is_trace);

    # close backend connection
    $client->terminate();

    my $conf = $config->config();
    my @extra_header;
    @extra_header = %{ $response->extra_headers() } if ($conf->{output}->{headers});
    if ($response->has_error()) {

        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            'charset' => 'utf8',
            @extra_header
        );
        print $response->error_message()."\n";

    } elsif ($response->is_pending()) {

        my $transaction_id = $response->transaction_id();
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            'charset' => 'utf8',
            '-retry-after' => $response->retry_after(),
            @extra_header
        );
        print "202 Request Pending - Retry Later ($transaction_id)\n";

    } else {

        # Default is base64 encoding, but we can turn on binary
        my $encoding = $conf->{output}->{encoding} || 'base64';
        my $out = $response->result;
        if ($encoding eq 'binary') {
            $out = decode_base64($out);
        } else {
            $encoding = 'base64';
        }
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => $mime,
            'content-length' => length $out,
            'content-transfer-encoding' => $encoding,
            'charset' => '',
            @extra_header
        );
        print $out;
    }

}
