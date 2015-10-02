#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use Digest::SHA qw(sha1_base64);
  
use Test::More tests => 3;

package main;

my $result;
my $client = TestCGI::factory();

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

ok((-s "tmp/entity.crt"),'Old cert present') || die;
 
# Generate new CSR
`openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=entity.openxpki.org" -nodes -keyout tmp/entity2.key -out tmp/entity2.csr 2>/dev/null`;
 
ok((-s "tmp/entity.csr"), 'csr present') || die; 

# do on behalf request with old certificate
`$sscep enroll -u http://localhost/scep/scep -K tmp/entity.key -O tmp/entity.crt -r tmp/entity2.csr -k tmp/entity2.key -c tmp/cacert-0 -l tmp/entity2.crt  -t 1 -n 1`;   

ok(-s "tmp/entity2.crt", "Renewed cert exists");

my $data = `openssl  x509 -in tmp/entity2.crt -outform der`;
my $cert_identifier = sha1_base64($data);
$cert_identifier =~ tr/+\//-_/;

diag('Cert Identifier '  . $cert_identifier);
    
open(CERT, ">tmp/entity2.id");
print CERT $cert_identifier;
close CERT;

