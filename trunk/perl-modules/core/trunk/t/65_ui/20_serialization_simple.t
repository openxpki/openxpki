
use strict;
use warnings;
use Test::More tests => 15;
use English;
use utf8; # otherwise the utf8 tests does not work
# use Smart::Comments;

BEGIN { use_ok( 'OpenXPKI::Serialization::Simple' ); }

print STDERR "OpenXPKI::Serialization::Simple\n";

# test illegal separators
eval
{
    OpenXPKI::Serialization::Simple->new
    ({
        SEPARATOR => "ab"
    });
};
ok($EVAL_ERROR, 'Multiple character separator -> exception');
eval
{
    OpenXPKI::Serialization::Simple->new
    ({
        SEPARATOR => "1"
    });
};
ok($EVAL_ERROR, 'Numeric separator -> exception');

# test default separator
my $ref = OpenXPKI::Serialization::Simple->new ();
ok($ref, 'Default seperator');

# using "-" to make testing easier
$ref = OpenXPKI::Serialization::Simple->new
             ({
                 SEPARATOR => "-"
             });
ok($ref, '- as seperator');

    my $hash = {
	"HEADER" => ["Testheader"],
	"UNDEFINED" => undef,
	"LIST"   => [
	    {"Name"   => ["John Doe"],
	     "Serial" => [10, 12],
	     "Undefined" => undef,
	    },
	    {"Name"   => ["Jane Doe"],
	     "Serial" => [11, 13]
	    }
	    ],
	"FOOTER" => ["OK", "Abort"]
    };

my $text = $ref->serialize ($hash);

my $expected_serialization = "HASH-328-6-FOOTER-ARRAY-31-0-SCALAR-2-OK-1-SCALAR-5-Abort-6-HEADER-ARRAY-23-0-SCALAR-10-Testheader-4-LIST-ARRAY-203-0-HASH-100-4-Name-ARRAY-20-0-SCALAR-8-John Doe-6-Serial-ARRAY-28-0-SCALAR-2-10-1-SCALAR-2-12-9-Undefined-UNDEF-1-HASH-82-4-Name-ARRAY-20-0-SCALAR-8-Jane Doe-6-Serial-ARRAY-28-0-SCALAR-2-11-1-SCALAR-2-13-9-UNDEFINED-UNDEF-";
is($text, $expected_serialization, 'Serialization outputs expected serialization');

my $res = $ref->deserialize($text);
ok($res, 'Deserialization produced a result');

is_deeply($res, $hash, "Data structure survived (de)serialization");

## check that undef really works
ok (not defined $hash->{'UNDEFINED'}, 'undefined hash');
ok (not defined $res->{'UNDEFINED'}, 'undefined ref');
ok (not defined $hash->{'LIST'}->[0]->{'UNDEFINED'}, 'undefined hash/array');
ok (not defined $res->{'LIST'}->[0]->{'UNDEFINED'}, 'undefined res/array');

## testing utf-8 encoding

$hash = {
	 "uid"   => ["Тестиров"],
         "cn"    => ["Иван Петров"]
        };
$text = $ref->serialize ($hash, 'utf8 serialization');

$expected_serialization = "HASH-92-2-cn-ARRAY-34-0-SCALAR-21-Иван Петров-3-uid-ARRAY-29-0-SCALAR-16-Тестиров-";
## downgrade from utf8 to byte level
$expected_serialization = pack ("C*", unpack ("U0C*", $expected_serialization));
is($text, $expected_serialization, 'UTF8 serialization produces expected result');

$res = $ref->deserialize($text);
ok($res, 'UTF8 serialized text deserialized');
is_deeply($res, $hash, "Data structure survived (de)serialization");

1;
