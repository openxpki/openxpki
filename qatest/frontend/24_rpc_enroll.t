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

use Test::More tests => 4;

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ua = LWP::UserAgent->new();

my $ssl_opts = {
    verify_hostname => 0,
    SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
    SSL_key_file => '/tmp/oxi-test/pkiclient.key',
    SSL_cert_file => '/tmp/oxi-test/pkiclient.crt',
    SSL_ca_file => '/tmp/oxi-test/chain.pem',
};
$ua->ssl_opts( %{$ssl_opts} );

my $pkcs10 = `openssl req -new -subj "/CN=testbox.openxpki.org" -nodes -keyout /dev/null 2>/dev/null`;

my $req = HTTP::Request->new('POST', 'https://localhost/rpc/enroll/RequestCertificate',
    HTTP::Headers->new( Content_Type => 'application/json'),
    encode_json({ pkcs10 => $pkcs10 })
);

my $response = $ua->request( $req );

ok($response->is_success);
my $json = JSON->new->decode($response->decoded_content);
is( $json->{result}->{state}, 'SUCCESS');
ok( $json->{result}->{data}->{certificate});
ok( $json->{result}->{data}->{chain});
