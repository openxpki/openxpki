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

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 8;

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ua = LWP::UserAgent->new();

$ua->ssl_opts( verify_hostname => 0,
    SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
    SSL_ca_file => 'tmp/chain.pem',
);

my $req = HTTP::Request->new('POST', 'https://localhost/rpc/enroll/TestConnection',
    HTTP::Headers->new( Content_Type => 'application/json'),
);

my $response = $ua->request( $req );

ok($response->is_success);
my $json = JSON->new->decode($response->decoded_content);
is( $json->{result}->{state}, 'REJECTED');
ok(! $json->{result}->{data}->{signer_cert_identifier});

$ua->ssl_opts( verify_hostname => 0,
    SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
    SSL_key_file => 'tmp/pkiclient.key',
    SSL_cert_file => 'tmp/pkiclient.crt',
    SSL_ca_file => 'tmp/chain.pem',
);

$req = HTTP::Request->new('POST', 'https://localhost/rpc/enroll/TestConnection',
    HTTP::Headers->new( Content_Type => 'application/json'),
);

$response = $ua->request( $req );

ok($response->is_success);
$json = JSON->new->decode($response->decoded_content);
is( $json->{result}->{state}, 'SUCCESS');
ok( $json->{result}->{data}->{signer_cert_identifier});
ok( $json->{result}->{data}->{signer_authorized});
ok( $json->{result}->{data}->{signer_trusted});
