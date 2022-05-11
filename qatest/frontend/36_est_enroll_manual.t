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

my $pkcs10 = `openssl req -new -subj "/CN=est-manual-test.openxpki.org" -nodes -newkey rsa:2048 -keyout tmp/estcert2.key -outform der | openssl base64 -e 2>/dev/null`;

my $response = $ua->post("https://$host/.well-known/est/simpleenroll",
    Content_Type => 'application/pkcs10', Content => $pkcs10 );

my $transaction_id = $response->header( 'X-Openxpki-Transaction-Id' );

note $response->status_line;
is($response->code, 202);

my $client = TestCGI::factory('democa');
# Log in and approve request
my $result = $client->mock_request({
    'action' => 'workflow!search',
    'wf_type' => 'certificate_enroll',
    'wf_token' => undef,
    'transaction_id' => $transaction_id,
});

ok($result->{goto});
like($result->{goto}, "/workflow!result!id/");

$result = $client->mock_request({
    page => $result->{goto},
});

my $workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
note 'Found workflow ' . $workflow_id;

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_approve_csr!wf_id!' . $workflow_id
});

$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

my $cert_identifier = $client->get_field_from_result('cert_identifier');

if (ref $cert_identifier) { $cert_identifier = $cert_identifier->{label}; }

ok($cert_identifier,'Cert Identifier found');
note $cert_identifier;


$response = $ua->post("https://$host/.well-known/est/simpleenroll",
    Content_Type => 'application/pkcs10', Content => $pkcs10 );

my $body = $response->decoded_content;

like($response->header( 'Content-Type' ),"/application/pkcs7-mime/");
like($body,"/\\A[a-zA-Z0-9\+\/ ]+=*\\z/xms");

open CERT, ">", "tmp/estclient2.p7";
print CERT "-----BEGIN PKCS7-----\n$body\n-----END PKCS7-----\n";
close CERT;

-e 'tmp/estclient2.crt' && unlink('tmp/estclient2.crt');
`openssl pkcs7 -in tmp/estclient2.p7 -print_certs > tmp/estclient2.crt`;
is($?,0);

ok(-f 'tmp/estclient2.crt');
