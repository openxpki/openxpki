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

package main;

my $host = 'localhost';

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ssl_opts = {
    verify_hostname => 0,
    SSL_ca_file => 'tmp/chain.pem',
};
$ua->ssl_opts( %{$ssl_opts} );

my $response = $ua->get("https://$host/.well-known/est/cacerts");
ok($response->is_success);

# EST seems to be picky on headers

my $length = $response->header( 'Content-Length' );
my $body = $response->decoded_content;
ok($length);
is($length, length($body));
like($body,"/\\A[a-zA-Z0-9\+\/ ]+=*\\z/xms");

$body =~ s{^\s*}{}gxms;
$body =~ s{\s*$}{}gxms;

open CHAIN, ">", "tmp/estchain.p7";
print CHAIN "-----BEGIN PKCS7-----\n$body\n-----END PKCS7-----\n";
close CHAIN;

`openssl pkcs7 -in tmp/estchain.p7 -print_certs > tmp/estchain.pem`;

$response = $ua->get("https://$host/.well-known/est/csrattrs");
ok($response->is_success);

$length = $response->header( 'Content-Length' );
$body = $response->decoded_content;
ok($length);
is($length, length($body));
like($body, "/^MCYGBysGAQEBARYGCSqGSIb3DQEJAQYFK4EEACIGCWCGSAFlAwQCAg==\\s*/");
