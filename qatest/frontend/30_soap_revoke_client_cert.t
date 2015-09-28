#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
# use IO::Socket::SSL qw(debug3);
use SOAP::Lite; # +trace => 'all';
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use Connector::Proxy::SOAP::Lite;

use Test::More tests => 7;

package main;

my $result;
my $client = TestCGI::factory();

my $cert_identifier = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<tmp/entity.id';
    <$HANDLE>;
};

diag('Revocation test - cert identifier '  . $cert_identifier);

# Unauthenticated call - stops in PENDING state
my $soap = SOAP::Lite 
    ->uri('http://schema.openxpki.org/OpenXPKI/SOAP/Revoke')
    ->proxy('http://localhost/soap/ca-one')
    ->RevokeCertificate($cert_identifier);

ok($soap, 'SOAP Client no Auth');
is($soap->result->{error},'','No error');
is($soap->result->{state}, 'PENDING','State pending without auth, Workflow ' . $soap->result->{id});

# Now try with SSL Auth - should be autoapproved
my $oSoap =  Connector::Proxy::SOAP::Lite->new({
    LOCATION => 'https://localhost/soap/ca-one',
    uri => 'http://schema.openxpki.org/OpenXPKI/SOAP/Revoke',
    method => 'RevokeCertificate',
    certificate_file => 'tmp/pkiclient.crt',
    certificate_key_file => 'tmp/pkiclient.key',
    ca_certificate_path => 'tmp',
    ssl_ignore_hostname => 1, # makes it easier
});    

my $res = $oSoap->get_hash($cert_identifier);

ok($soap, 'SOAP Client with Auth');
is($soap->result->{error},'','No error');
is($soap->result->{state}, 'SUCCESS','State SUCCESS with auth,  Workflow ' . $soap->result->{id});

# Check the certificate status via webui
$result = $client->mock_request({
    page => 'certificate!detail!identifier!'.$cert_identifier
});

while (my $line = shift @{$result->{main}->[0]->{content}->{data}}) {
    is( $line->{value}->{value} , 'CRL_ISSUANCE_PENDING', 'certifiacte status is CRL Pending') if ($line->{format} && $line->{format} eq 'certstatus');
}

