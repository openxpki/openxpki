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

my $cert_identifier = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<tmp/entity.id';
    <$HANDLE>;
};
chomp $cert_identifier;

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

my $response = $ua->get('https://localhost/rpc/?method=RevokeCertificateByIdentifier&reason_code=superseded&cert_identifier='.$cert_identifier);

ok($response->is_success);

my $json = JSON->new->decode($response->decoded_content);

diag('Workflow Id ' . $json->{result}->{id} );

is($json->{result}->{state}, 'CHECK_FOR_REVOCATION');