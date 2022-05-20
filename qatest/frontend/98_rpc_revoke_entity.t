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

use Test::More tests => 2;

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

my $req = HTTP::Request->new('POST', 'https://localhost/rpc/enroll/RevokeCertificateByEntity',
    HTTP::Headers->new( Content_Type => 'application/json'),
    encode_json({ entity => 'entity.openxpki.org', reason_code => 'unspecified' })
);

my $response = $ua->request( $req );

ok($response->is_success);
my $json = JSON->new->decode($response->decoded_content);
# should be an empty query if all was revoked before, if not does cleanup
is( $json->{result}->{state}, 'FAILURE');
