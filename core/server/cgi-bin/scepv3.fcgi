#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Fast;
use Data::Dumper;
use English;
use MIME::Base64;
use OpenXPKI::Client::Config;
use OpenXPKI::Client::Service::SCEP;

my $config = OpenXPKI::Client::Config->new('scep');
my $log = $config->logger();
$log->info("SCEP handler initialized");

while (my $cgi = CGI::Fast->new()) {

    my $conf = $config->parse_uri()->config();

    my $server = $conf->{global}->{servername} || $config->endpoint();
    if (!$server) {
        print $cgi->header(
           -type => 'text/plain',
           -status => '404 Not Found (no such server)'
        );
        print 'server not set - unknown endpoint';
        $log->error('server not set - unknown endpoint and no default set');
        next;
    }

    my $log = $config->logger();
    Log::Log4perl::MDC->put('server', $server);

    my $operation = $cgi->url_param('operation') || '';

    if ($operation !~ m{\A(PKIOperation|GetCert(Initial)?|GetCRL|Get(Next)?CACert|GetCACaps)\z}) {
        print $cgi->header( -status => '400 Bad Request', -type => 'text/plain');
        print "Invalid operation\n";
        $log->error('Invalid operation ' . $operation);
        next;
    }

    $log->debug(sprintf("Incoming SCEP operation %s on endpoint %s", $operation, $config->endpoint()));
    my $message;
    if ($operation eq 'PKIOperation') {
        # get the message from the GET string and decode base64
        if ($cgi->request_method() eq 'GET') {
            $message = $cgi->url_param('message');
            $log->debug("Got PKIOperation via GET");
        } else {
            $message = encode_base64($cgi->param('POSTDATA'),'');
            if (!$message) {
                $log->error("POSTDATA is empty - check documentation on required setup for Content-Type headers!");
                $log->debug("Content-Type is " . ($ENV{'CONTENT_TYPE'} || 'undefined'));
                print $cgi->header(
                    -type => 'text/plain',
                    -status => '400 Bad Request (empty body)'
                );
                print 'Bad Request - body is empty';
                next;
            }
            $log->debug("Got PKIOperation via POST");
        }
        $log->trace("Decoded SCEP message " . $message) if ($log->is_trace);
    }

    my $client = OpenXPKI::Client::Service::SCEP->new(
        config => $config,
        logger => $log,
        operation => $operation
    );

    $log->debug("Config created");

    my $response;
    my @extra_header;
    if ($operation eq 'PKIOperation') {

        # this internally triggers a call to the backend to unwrap the
        # scep message and returns the payload and some attributes
        # will die in case of an error, so an eval is needed here!
        eval{ $client->pkcs7message( $message ); };

        # something is wrong, TODO we might try to branch request vs. server errors
        if ($EVAL_ERROR) {
            $response = OpenXPKI::Client::Service::Response->new( 50010 );

        } elsif (!$client->attr()->{alias}) {
            $response = OpenXPKI::Client::Service::Response->new ( 40002 );
            $log->info('Unable to find RA certficate');
        } elsif (!$client->signer) {
            $response = OpenXPKI::Client::Service::Response->new ( 40001 );
            $log->info('Unable to extract signer certficate');
        # Enrollment request
        } elsif ($client->message_type =~ m{(PKCSReq|RenewalReq|GetCertInitial)}) {
            # TODO - improve handling of GetCertInitial and RenewalReq
            $log->debug("Handle enrollment");
            $response = $client->handle_enrollment_request($cgi);
        # Request for CRL or GetCert with IssuerSerial in Payload
        } else {
            $response = $client->handle_property_request($cgi, $client->message_type);
        }

        @extra_header = %{ $response->extra_headers() } if ($conf->{output}->{headers});
        $log->debug('Status: ' . $response->http_status_line());
        $log->trace(Dumper $response) if ($log->is_trace);

        if (!$response->is_server_error()) {
            my $out = $client->generate_pkcs7_response( $response );
            $log->trace($out) if ($log->is_trace);
            $out = decode_base64($out);
            print $cgi->header(
                -status => $response->http_status_line(),
                -type => 'application/x-pki-message',
                -charset => '',
                'content-length' => length $out,
                @extra_header
            );
            print $out;
        }
        # close backend connection
        $client->terminate();

        next;
    }

    my $mime;
    if ($operation eq 'GetCACaps') {
        $mime = 'text/plain';
        $response = $client->handle_property_request($cgi);
    }

    if ($operation eq 'GetCACert') {
        $mime = 'application/x-x509-ca-ra-cert';
        $response = $client->handle_property_request($cgi);
    }

    if ($operation eq 'GetNextCACert') {
        $mime = 'application/x-x509-next-ca-cert';
        $response = $client->handle_property_request($cgi);
    }

    @extra_header = %{ $response->extra_headers() } if ($conf->{output}->{headers});
    if ($response->is_server_error()) {
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            'charset' => 'utf8',
            @extra_header
        );
        print $response->error_message()."\n";
        $log->debug($response->error_message()) if ($log->is_trace);
    } elsif ($mime eq 'text/plain') {
        # we MUST NOT set a charset header here as older sscep versions
        # check on a literal "text/plain" which breaks with a charset.
        # As this branch applies only to GetCACaps which is 7bit ASCII
        # no charset header should be required at all - also make sure
        # to have "AddDefaultCharset off"
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => 'text/plain',
            'charset' => '',
            'content-length' => length $response->result,
            @extra_header
        );
        print $response->result;
        $log->trace($response->result) if ($log->is_trace);
    } else {
        my $out = decode_base64($response->result);
        print $cgi->header(
            -status => $response->http_status_line(),
            -type => $mime,
            -charset => '',
            'content-length' => length $out,
            @extra_header
        );
        print $out;
        $log->trace($response->result) if ($log->is_trace);
    }
}
