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

use Test::More tests => 12;

package main;

my $host = '10.16.6.42:8085';
#$host = 'localhost';

sub LWP::UserAgent::get_basic_credentials {
    my ($self, $realm, $url, $isproxy) = @_;
    return 'estuser', 'estpwd';
}

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
like($body,"/[a-z0-9 ]+/");

print $body ;

$response = $ua->get("https://$host/.well-known/est/csrattrs");
ok($response->is_success);

$length = $response->header( 'Content-Length' );
$body = $response->decoded_content;
ok($length);
is($length, length($body));
is($body,"MCYGBysGAQEBARYGCSqGSIb3DQEJAQYFK4EEACIGCWCGSAFlAwQCAg==");

my $pkcs10 = `openssl req -new -subj "/CN=est-test.openxpki.org" -nodes -newkey rsa:1024 -keyout tmp/estcert.key -outform der | openssl base64 -e 2>/dev/null`;

$response = $ua->post("https://$host/.well-known/est/simpleenroll",
    Content_Type => 'application/pkcs10', Content => $pkcs10 );

$length = $response->header( 'Content-Length' );
$body = $response->decoded_content;

print $body ;

ok($response->is_success);
ok($length);
is($length, length($body));
like($body,"/[a-z0-9 ]+/");

