#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
  
use Test::More tests => 9;

package main;

my $result;
my $client = TestCGI::factory();

my $crl= do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<tmp/crl.txt';
    <$HANDLE>;
};

for my $cert (('entity','entity2','pkiclient')) {
 
    diag('Testing '  .$cert);       
    # Load cert status page using cert identifier
    my $cert_identifier = do { # slurp
        local $INPUT_RECORD_SEPARATOR;
        open my $HANDLE, "<tmp/$cert.id";
        <$HANDLE>;
    };
    
    $result = $client->mock_request({
        'page' => 'certificate!detail!identifier!'.$cert_identifier 
    });
    
    # check database status 
    is($result->{main}->[0]->{content}->{data}->[6]->{value}->{value}, 'REVOKED');
    
    # extract serial for checking against crl
    my $serial = $result->{main}->[0]->{content}->{data}->[2]->{value};
    
    diag($serial);
    like( $serial, "/0x[0-9a-f]+/", 'Got serial');
    
    $serial = uc(substr($serial,2));
    
    ok($crl =~ /$serial/m, 'Serial found on CRL');

}
