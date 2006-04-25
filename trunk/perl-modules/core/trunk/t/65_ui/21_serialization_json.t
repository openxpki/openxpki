
use strict;
use warnings;
use Test::More tests => 3;
use English;

BEGIN { use_ok( 'OpenXPKI::Serialization::JSON' ); }

print STDERR "OpenXPKI::Serialization::JSON\n";

SKIP: {
    my $ref = OpenXPKI::Serialization::JSON->new();
    skip "OpenXPKI::Serialization::JSON not usable", 2 unless defined $ref;

    my $hash = {
	"HEADER" => ["Testheader"],
	"LIST"   => [
	    {"Name"   => ["John Doe"],
	     "Serial" => [10, 12]
	    },
	    {"Name"   => ["Jane Doe"],
	     "Serial" => [11, 13]
	    }
	    ],
	"FOOTER" => ["OK", "Abort"]
    };

    my $text = $ref->serialize ($hash);

    my $expected_serialization = '{"FOOTER":["OK","Abort"],"LIST":[{"Name":["John Doe"],"Serial":[10,12]},{"Name":["Jane Doe"],"Serial":[11,13]}],"HEADER":["Testheader"]}';
    ok($text eq $expected_serialization);
    
    my $res = $ref->deserialize($text);
    is_deeply($res, $hash, "Data structure survived (de)serialization");
}
    
1;
