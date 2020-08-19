use strict;
use warnings;

# Core modules
use Test::More tests => 4;
use Test::Exception;
use Test::Deep;

BEGIN { use_ok( 'OpenXPKI::Serialization::JSON' ); }

my $obj;
lives_ok { $obj = OpenXPKI::Serialization::JSON->new() } "new instance";

my $hash = {
    "HEADER" => ["Testheader"],
    "UNDEFINED" => undef,
    "LIST" => [
        [
            {"Name"   => ["John Doe"]},
            {"Serial" => [10, 12]},
            {"Undefined" => undef},
        ],
        [
            {"Name"   => ["Jane Doe"] },
            {"Serial" => [11, 13] }
        ],
    ],
    "FOOTER" => ["OK", "Abort"],
};

my $serialized;

lives_and {
    $serialized = $obj->serialize ($hash);
    like($serialized, "/{.*}/" );
} "serialize";

lives_and {
    my $res = $obj->deserialize($serialized);
    cmp_deeply($res, $hash);
} "deserialize";

1;
