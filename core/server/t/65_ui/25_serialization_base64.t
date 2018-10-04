use strict;
use warnings;
use Test::More tests => 4;
use English;
use utf8; # otherwise the utf8 tests does not work
# use Smart::Comments;

use MIME::Base64;

BEGIN { use_ok( 'OpenXPKI::Serialization::Simple' ); }

print STDERR "OpenXPKI::Serialization::Simple\n" if $ENV{VERBOSE};

# test default separator
my $ref = OpenXPKI::Serialization::Simple->new ();
ok($ref, 'Default seperator');

my $binary = decode_base64("MIIJGQIBAzCCCN8GCSqGSIb3DQEHAaCCCNAEggjMMIIIyDCCA38GCSqGSIb3DQEHBqCCA3AwggNs");

my $b64 = $ref->serialize( $binary );

is($b64, "OXB64:MIIJGQIBAzCCCN8GCSqGSIb3DQEHAaCCCNAEggjMMIIIyDCCA38GCSqGSIb3DQEHBqCCA3AwggNs\n");

my $bin = $ref->deserialize( $b64 );

ok(pack('H*', $bin) eq  pack('H*', $binary));

my $hash = { 'BIN' => $binary };

$b64 = $ref->serialize( $hash );

print "\n----$b64----\n";

my $hash2 = $ref->deserialize( $b64 );
