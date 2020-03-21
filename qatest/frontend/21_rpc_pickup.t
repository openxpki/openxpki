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
use Digest::SHA qw(sha1_hex);
use Crypt::PKCS10;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 9;

package main;

# Create the pkcs10
my $pkcs10 = `openssl req -new -subj "/CN=entity-rpc2.openxpki.org" -nodes -keyout tmp/entity-rpc.key 2>/dev/null`;

ok( $pkcs10  , 'csr present') || die;

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ssl_opts = {
    verify_hostname => 0,
    SSL_ca_file => 'tmp/chain.pem',
};
$ua->ssl_opts( %{$ssl_opts} );

Crypt::PKCS10->setAPIversion(1);
my $decoded = Crypt::PKCS10->new($pkcs10, ignoreNonBase64 => 1, verifySignature => 0);
my $transaction_id = sha1_hex($decoded->csrRequest);

my $response = $ua->post('https://localhost/rpc/request', [
    method => 'RequestCertificate',
    pkcs10 => $pkcs10,
    comment => 'Automated request',
    ],
);

ok($response->is_success);

my $json = JSON->new->decode($response->decoded_content);

diag('Workflow Id ' . $json->{result}->{id} );

my $wf_id =  $json->{result}->{id};

is($json->{result}->{state}, 'FAILURE');

is($json->{result}->{data}->{transaction_id}, $transaction_id , 'Transaction Id ');

$response = $ua->post('https://localhost/rpc/request', [
    method => 'RequestCertificate',
    pkcs10 => $pkcs10,
    comment => 'Automated request',
    transaction_id => $json->{result}->{data}->{transaction_id},
    ],
);
ok($response->is_success);

$json = JSON->new->decode($response->decoded_content);
is($wf_id,  $json->{result}->{id}, 'Pickup with same id');

# pickup with text/plain

$response = $ua->post('https://localhost/rpc/request', [
    method => 'RequestCertificate',
    pkcs10 => $pkcs10,
    comment => 'Automated request',
    transaction_id => $json->{result}->{data}->{transaction_id},
    ],
    Accept => 'text/plain'
);
ok($response->is_success);
like($response->decoded_content,qr/id=$wf_id/);
like($response->decoded_content,qr/data.error_code=I18N_OPENXPKI_UI_ENROLLMENT_ERROR_SIGNER_NOT_AUTHORIZED/);
