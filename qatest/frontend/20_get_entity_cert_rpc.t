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

package main;

# Create the pkcs10
my $pkcs10 = `openssl req -new -subj "/CN=entity2.openxpki.org" -nodes -keyout tmp/entity-rpc.key 2>/dev/null`;
 
ok( $pkcs10  , 'csr present') || die; 

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";
        
my $ssl_opts = { 
    verify_hostname => 0,
    SSL_key_file => 'tmp/pkiclient.key',
    SSL_cert_file => 'tmp/pkiclient.crt',
    SSL_ca_file => 'tmp/chain.pem',
};
$ua->ssl_opts( %{$ssl_opts} );

my $response = $ua->post('https://localhost/rpc/request', [
    method => 'RequestCertificate',
    pkcs10 => $pkcs10,
    comment => 'Automated request',
    ]
);

ok($response->is_success);
print Dumper $response->decoded_content;

my $json = JSON->new->decode($response->decoded_content);

diag('Workflow Id ' . $json->{result}->{id} );

is($json->{result}->{state}, 'CHECK_FOR_REVOCATION');