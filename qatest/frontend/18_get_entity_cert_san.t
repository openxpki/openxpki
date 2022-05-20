#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use MIME::Base64;

use Test::More tests => 16;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

SKIP: { skip 'sscep not available', 16 if (system "$sscep > /dev/null 2>&1");

`$sscep getca -c /tmp/oxi-test/cacert -u http://localhost/scep/scep`;

ok((-s "/tmp/oxi-test/cacert-0"),'CA certs present') || die;

`rm -f /tmp/oxi-test/entity-san.*`;

# Create the pkcs10
`openssl req -new -nodes -keyout /tmp/oxi-test/entity-san.key -out /tmp/oxi-test/entity-san.csr  -subj "/CN=entity-san.openxpki.org" -config openssl.conf -reqexts req_san 2>/dev/null`;

ok((-s "/tmp/oxi-test/entity-san.csr"), 'csr present') || die;

# do on behalf request with pkiclient certificate
my $scep = `$sscep enroll -v -u http://localhost/scep/scep -M custid=12345 -K /tmp/oxi-test/pkiclient.key -O /tmp/oxi-test/pkiclient.crt -r /tmp/oxi-test/entity-san.csr -k /tmp/oxi-test/entity-san.key -c /tmp/oxi-test/cacert-0 -l /tmp/oxi-test/entity-san.crt  -t 1 -n 1 |  grep "Read request with transaction id"`;

my @t = split(/:\s+/, $scep);
my $sceptid = $t[2];

diag("Transaction Id: $sceptid");

# Log in and approve request
$result = $client->mock_request({
    'action' => 'workflow!search',
    'wf_type' => 'certificate_enroll',
    'wf_token' => undef,
    'transaction_id' => $sceptid,
});

ok($result->{goto});
like($result->{goto}, "/workflow!result!id/");

$result = $client->mock_request({
    page => $result->{goto},
});

my $workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
diag('Found workflow ' . $workflow_id );

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_approve_csr!wf_id!' . $workflow_id
});

# load raw context to find certificate id
my $cert_identifier;
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

foreach my $item (@{$result->{main}->[0]->{content}->{data}}) {
    $cert_identifier = $item->{value}->{label} if ($item->{label} eq 'cert_identifier');
}

ok($cert_identifier,'Cert Identifier found');
diag($cert_identifier);

# fetch cert with sscep
`$sscep enroll -u http://localhost/scep/scep -K /tmp/oxi-test/pkiclient.key -O /tmp/oxi-test/pkiclient.crt -r /tmp/oxi-test/entity-san.csr -k /tmp/oxi-test/entity-san.key -c /tmp/oxi-test/cacert-0 -l /tmp/oxi-test/entity-san.crt  -t 1 -n 1`;

ok(-e "/tmp/oxi-test/entity-san.crt", "Cert exists");

open(CERT, ">/tmp/oxi-test/entity-san.id");
print CERT $cert_identifier;
close CERT;


my $san = `openssl x509 -noout -text -in /tmp/oxi-test/entity-san.crt | grep -A1 "X509v3 Subject Alternative Name" | tail -n1`;

like($san, qr/DNS:also.test.me/);
like($san, qr/DNS:test.me/);
like($san, qr/IP Address:127.0.0.1/);
like($san, qr/IP Address:FE80:0:0:0:0:0:0:1/);


# Create pkcs10 for renewal
`openssl req -new -nodes -keyout /tmp/oxi-test/entity-san-renew.key -out /tmp/oxi-test/entity-san-renew.csr  -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=entity-san.openxpki.org" -config openssl.conf 2>/dev/null`;

ok((-s "/tmp/oxi-test/entity-san-renew.csr"), 'csr present') || die;

# do on behalf request with old certificate
`$sscep enroll -v -u http://localhost/scep/scep -M custid=12346 -K /tmp/oxi-test/entity-san.key -O /tmp/oxi-test/entity-san.crt -r /tmp/oxi-test/entity-san-renew.csr -k /tmp/oxi-test/entity-san-renew.key -c /tmp/oxi-test/cacert-0 -l /tmp/oxi-test/entity-san-renew.crt  -t 1 -n 1 |  grep "Read request with transaction id"`;


ok(-e "/tmp/oxi-test/entity-san-renew.crt");

$san = `openssl x509 -noout -text -in /tmp/oxi-test/entity-san-renew.crt | grep -A1 "X509v3 Subject Alternative Name" | tail -n1`;

like($san, qr/DNS:also.test.me/);
like($san, qr/DNS:test.me/);
like($san, qr/IP Address:127.0.0.1/);
like($san, qr/IP Address:FE80:0:0:0:0:0:0:1/);

}
