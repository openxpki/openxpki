#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 2;

package main;

my $result;
my $client = TestCGI::factory('democa');

my @cert_identifier;

-d "/tmp/oxi-test" or mkdir "/tmp/oxi-test";

my @files = </tmp/oxi-test/*>;
foreach my $file (@files) {
    note 'Unlink '  .$file;
    # Load cert status page using cert identifier
    unlink $file;
}

`echo "" | openssl s_client -connect localhost:443  -showcerts | openssl crl2pkcs7 -nocrl -certfile /dev/stdin  | openssl pkcs7 -print_certs > /tmp/oxi-test/chain.pem`;

ok(-d "/tmp/oxi-test/");
ok(-s "/tmp/oxi-test/chain.pem");