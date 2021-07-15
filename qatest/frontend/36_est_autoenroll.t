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

use Test::More tests => 6;

package main;

my $host = 'localhost';

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ssl_opts = {
    verify_hostname => 0,
    SSL_ca_file => 'tmp/chain.pem',
    SSL_key_file => 'tmp/pkiclient.key',
    SSL_cert_file => 'tmp/pkiclient.crt',
};
$ua->ssl_opts( %{$ssl_opts} );

my $pkcs10 = `openssl req -new -subj "/CN=est-test.openxpki.org" -nodes -newkey rsa:2048 -keyout tmp/estcert.key -outform der | openssl base64 -e 2>/dev/null`;

my $response = $ua->post("https://$host/.well-known/est/simpleenroll",
    Content_Type => 'application/pkcs10', Content => $pkcs10 );

my $length = $response->header( 'Content-Length' );
my $body = $response->decoded_content;

ok($response->is_success);
ok($length);
is($length, length($body));
like($body,"/\\A[a-zA-Z0-9\+\/ ]+=*\\z/xms");

$body =~ s{^\s*}{}gxms;
$body =~ s{\s*$}{}gxms;

open CERT, ">", "tmp/estclient.p7";
print CERT "-----BEGIN PKCS7-----\n$body\n-----END PKCS7-----\n";
close CERT;

-e 'tmp/estclient.crt' && unlink('tmp/estclient.crt');
`openssl pkcs7 -in tmp/estclient.p7 -print_certs > tmp/estclient.crt`;
is($?,0);

ok(-f 'tmp/estclient.crt');


