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

use Test::More tests => 1;

package main;

my $result;
my $client = TestCGI::factory('democa');

my @cert_identifier;

-d "tmp/" || mkdir "tmp/";

my @files = <tmp/*>;
foreach my $file (@files) {

    diag('Unlink '  .$file);
    # Load cert status page using cert identifier
    unlink $file;
}

ok(-d "tmp/");