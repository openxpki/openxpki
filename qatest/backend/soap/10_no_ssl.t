#!/usr/bin/perl

use lib qw(../../lib);
use strict;
use warnings;
use English;
use Data::Dumper;
use SOAP::Lite;
use Log::Log4perl qw(:easy);
use MockUI;

use Test::More tests => 1;

package main;

my $client = MockUI::factory();

$client->mock_request({ 'page' => 'certificate!search' }); 
my $result = $client->mock_request({
    'action' => 'certificate!search',
    'status' => 'VALID',
    'subject' => 'cn=www.example.de'
});

print Dumper $result;
   
my $soap = SOAP::Lite 
    ->uri('http://my.own.site.com/OpenXPKI/SOAP/Revoke')
    ->proxy('http://localhost/soap/ca-one')
    ->RevokeCertificate('totallyrandomstring')
    ->result;

# This means the request failed (invalid cert identifier)
# but indicated that the soap connector is working    
is($soap, 1);