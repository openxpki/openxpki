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
    $ENV{REQUEST_URI} =~ m{.well-known/est/((\w+)/)?(cacerts|simpleenroll|simplereenroll|csrattrs)};
    my $label = $2 || 'default';
    my $operation = $3;

    if (!$operation) {
        print $cgi->header( -status => '501 Not implemented', -type => 'text/plain');
        print "Method not implemented\n";
        $log->error('Method not implemented');
        next;
    }

    $log->trace(sprintf("Incoming EST request %s on endpoint %s", $operation, $label));

    # set label as endpoint
    $config->endpoint($label);

    if ( lc( $ENV{HTTPS} // '' ) eq 'on') {
        # what we expect -> noop
    } elsif ($config->load_config()->{global}->{insecure}) {
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
    );

    my $response;
    my $mime = "application/pkcs7-mime; smime-type=certs-only";
    if ($operation eq 'cacerts') {
        $response = $client->handle_property_request($cgi, $operation);
    } elsif($operation eq 'csrattrs') {
        $mime = "application/csrattrs";
        $response = $client->handle_property_request($cgi, $operation);
    } else {
        $response = $client->handle_enrollment_request($cgi, $operation);
    }

    $log->debug('Status: ' . $response->http_status_line());
    $log->trace(Dumper $response) if ($log->is_trace);

    if ($response->has_error()) {

        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            'charset' => 'utf8',
        );
        print $response->error_message()."\n";

    } elsif ($response->is_pending()) {

        my $transaction_id = $response->transaction_id();
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            'charset' => 'utf8',
            '-retry-after' => $response->retry_after(),
            'x-openxpki-transaction-id' => $transaction_id,
        );
        print "202 Request Pending - Retry Later ($transaction_id)\n";

    } else {

        # Default is base64 encoding, but we can turn on binary
        my $conf = $config->load_config();
        my $encoding = $conf->{global}->{encoding} || 'base64';
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
            'charset' => ''
        );
        print $out;
    }

}
