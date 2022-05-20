#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';
SKIP: { skip 'sscep not available', 12 if (system "$sscep > /dev/null 2>&1");

my $crl= do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '</tmp/oxi-test/crl.txt';
    <$HANDLE>;
};

for my $cert (('entity','entity2','pkiclient')) {

    ok(-e "/tmp/oxi-test/$cert.id", "No such cert $cert.id") or next;

    # Load cert status page using cert identifier
    my $cert_identifier = do { # slurp
        local $INPUT_RECORD_SEPARATOR;
        open my $HANDLE, "</tmp/oxi-test/$cert.id";
        <$HANDLE>;
    };

    note 'Testing '  .$cert . ' / ' .$cert_identifier;

    $result = $client->mock_request({
        'page' => 'certificate!detail!identifier!'.$cert_identifier
    });

    my $serial;
    my $status;

    foreach my $item (@{$result->{main}->[0]->{content}->{data}}) {
        # check database status
        $status = $item->{value}->{value} if ($item->{label} eq 'Status');
        $serial = $item->{value}->[0] if ($item->{label} eq 'Certificate Serial');
    }

    is($status, 'REVOKED');

    note $serial;
    like( $serial, "/[0-9a-f]+/", 'Got serial');
    ok($crl =~ /\s$serial\s/im, 'Serial found on CRL');

}

}

done_testing();