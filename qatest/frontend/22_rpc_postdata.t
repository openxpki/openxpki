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

use Test::More tests => 3;

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ua = LWP::UserAgent->new();

my $ssl_opts = {
    verify_hostname => 0,
    SSL_ca_file => 'tmp/chain.pem',
};
$ua->ssl_opts( %{$ssl_opts} );

my $req = HTTP::Request->new('POST', 'https://localhost/rpc/search',
    HTTP::Headers->new( Content_Type => 'application/json'),
    encode_json({ method => "SearchCertificate", common_name => 'testbox.openxpki.org:pkiclient'})
);

my $response = $ua->request( $req );

ok($response->is_success);
my $json = JSON->new->decode($response->decoded_content);
is( $json->{result}->{state}, 'SUCCESS');
ok( $json->{result}->{data}->{cert_identifier});
