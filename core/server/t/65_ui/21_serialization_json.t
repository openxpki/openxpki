
use strict;
use warnings;
use Test::More tests => 3;
use English;

# use Smart::Comments;

BEGIN { use_ok( 'OpenXPKI::Serialization::JSON' ); }

print STDERR "OpenXPKI::Serialization::JSON\n" if $ENV{VERBOSE};


my $ref = OpenXPKI::Serialization::JSON->new();

my $hash = {
"HEADER" => ["Testheader"],
"UNDEFINED" => undef,
"LIST"   => [
    [
        {"Name"   => ["John Doe"]},
        {"Serial" => [10, 12]},
        {"Undefined" => undef},
    ],
    [
        {"Name"   => ["Jane Doe"] },
        {"Serial" => [11, 13] }    
    ],
    "FOOTER" => ["OK", "Abort"]
    ]
};

my $text = $ref->serialize ($hash);

my $expected_serialization = '{"LIST":[[{"Name":["John Doe"]},{"Serial":[10,12]},{"Undefined":null}],[{"Name":["Jane Doe"]},{"Serial":[11,13]}],"FOOTER",["OK","Abort"]],"HEADER":["Testheader"],"UNDEFINED":null}';
is($text,  $expected_serialization);

my $res = $ref->deserialize($text);
is_deeply($res, $hash, "Data structure survived (de)serialization");
    
1;
