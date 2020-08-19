use strict;
use warnings;

# Core modules
use Test::More tests => 6;
use Test::Exception;
use Test::Deep;
use MIME::Base64;

BEGIN { use_ok( 'OpenXPKI::Serialization::Simple' ); }

my $obj;
lives_ok { $obj = OpenXPKI::Serialization::Simple->new() } "new instance";

my $binary = decode_base64("MIIJGQIBAzCCCN8GCSqGSIb3DQEHAaCCCNAEggjMMIIIyDCCA38GCSqGSIb3DQEHBqCCA3AwggNs");

my $b64;
lives_and {
    $b64 = $obj->serialize( $binary );
    is($b64, "OXB64:MIIJGQIBAzCCCN8GCSqGSIb3DQEHAaCCCNAEggjMMIIIyDCCA38GCSqGSIb3DQEHBqCCA3AwggNs");
} "serialize";

my $bin;
lives_and {
    $bin = $obj->deserialize( $b64 );
    ok(pack('H*', $bin) eq pack('H*', $binary));
} "deserialize";

my $hash = { 'BIN' => $binary };

my $serialized;
lives_and {
    $serialized = $obj->serialize( $hash );
    like($serialized, qr/^OXJSF1:/);
} "serialize as hash, circumventing binary data detection";

lives_and {
    my $hash2 = $obj->deserialize( $serialized );
    cmp_deeply($hash, $hash2);
} "deserialize hash";

1;
