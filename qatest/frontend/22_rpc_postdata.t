#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use IO::Socket::SSL;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use Test::More;
use Test::Deep;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

our $url = 'https://localhost/rpc/public';

my $ua = LWP::UserAgent->new();

my $ssl_opts = {
    verify_hostname => 0,
    SSL_ca_file => 'tmp/chain.pem',
};
$ua->ssl_opts( %{$ssl_opts} );

sub json_response_equals($$$) {
    my ($req_hash, $expected_data, $msg) = @_;

    my $req = HTTP::Request->new(
        'POST' => $url,
        [ 'content-type' => 'application/json; charset=UTF-8' ],
        encode_json($req_hash),
    );
    return response_equals($req, $expected_data, $msg);
}

sub form_response_equals($$$) {
    my ($req_hash, $expected_data, $msg) = @_;

    my $req = POST $url, [ %{ $req_hash } ];
    return response_equals($req, $expected_data, $msg);
}

sub response_equals($$) {
    my ($req, $expected_data, $msg) = @_;

    note "\n".$req->as_string."\n";

    my $response = $ua->request( $req );
    my $json = JSON->new->decode($response->decoded_content);

    cmp_deeply $json, superhashof($expected_data), $msg;
}

# request
my $req1 = {
    'method' => "SearchCertificate",
    'common_name' => 'testbox.openxpki.org:pkiclient',
};
# expected result
my $response1 = {
    'result' => superhashof({
        'state' => 'SUCCESS',
        'data' => superhashof({
            'cert_identifier' => re(qr/^.+$/),
        }),
    }),
};

json_response_equals($req1, $response1, 'process request with JSON data');
form_response_equals($req1, $response1, 'process request with form data');

form_response_equals(
    # request
    {
        'method' => "SearchCertificate",
        'common_name' => "\x{FDD0}",
    },
    # expected result
    {
        'error' => superhashof({
            'message' => re(qr/invalid.*utf8/i),
        }),
    },
    'detect invalid UTF8 bytes',
);

done_testing();
