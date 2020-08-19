use strict;
use warnings;

# Core modules
use Test::More tests => 17;
use Test::Exception;
use Test::Deep;

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

use English;
use utf8; # otherwise the utf8 tests does not work


sub throw_oxi_exception {
    my ($obj, $serialized_data, $error, $test_name) = @_;

    subtest "$test_name" => sub {
        my $res;
        eval { $res = $obj->deserialize($serialized_data) };

        ok($EVAL_ERROR, "error thrown");

        my $exception = OpenXPKI::Exception->caught();
        ok(defined $exception, "some exception caught") or diag $EVAL_ERROR;
        is($exception->message, $error, "correct exception message");
    };
}


BEGIN { use_ok( 'OpenXPKI::Serialization::Simple' ); }

my $obj;
lives_ok { $obj = OpenXPKI::Serialization::Simple->new() } "new instance";

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
    like($serialized, qr/OXJSF1:\{.*\}/);
} "serialize";

my $res;
lives_and {
    $res = $obj->deserialize($serialized);
    cmp_deeply($res, $hash);
} "deserialize";

## testing utf-8 encoding

$hash = { "cn"    => ["Иван Петров"] };
$serialized = $obj->serialize ($hash, 'utf8 serialization');

my $expected_serialization = qq(OXJSF1:{"cn":["Иван Петров"]});
## downgrade from utf8 to byte level
#$expected_serialization = pack ("C*", unpack ("U0C*", $expected_serialization));
is($serialized, $expected_serialization, 'UTF8 serialization produces expected result');

$res = $obj->deserialize($serialized);
ok($res, 'UTF8 serialized text deserialized');
is_deeply($res, $hash, "Data structure survived (de)serialization");

##########################################################################
# more in-depth testing of deserialization
my $serialized_data = "";
my $exception = "";

# unknown data type ("MYTYPE")
throw_oxi_exception $obj, "MYTYPE-3-abc-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_DATA_TYPE_NOT_SUPPORTED",
    "unknown data type";

# wrong scalar format (length format corrupted)
throw_oxi_exception $obj, "SCALAR-3a-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_SCALAR_FORMAT_CORRUPTED",
    "wrong scalar format";

# wrong scalar length (10 instead of 3)
throw_oxi_exception $obj, "SCALAR-10-abc-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_SCALAR_DENOTED_LENGTH_TOO_LONG",
    "wrong scalar length";

# wrong array format (length format corrupted)
throw_oxi_exception $obj, "ARRAY-xxx-0-SCALAR-3-ccc-1-SCALAR-5-abcde-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_LENGTH_FORMAT_CORRUPTED",
    "wrong array length format";

# wrong array format (element position format corrupted)
throw_oxi_exception $obj, "ARRAY-32-xxx-SCALAR-3-ccc-1-SCALAR-5-abcde-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_ELEMENT_POSITION_FORMAT_CORRUPTED",
    "wrong array element position format";

# wrong array length (10 instead of 32)
throw_oxi_exception $obj, "ARRAY-10-0-SCALAR-3-ccc-1-SCALAR-5-abcde-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_LENGTH_CORRUPTED",
    "wrong array length";

# wrong hash format (length format corrupted)
throw_oxi_exception $obj, "HASH-xyz-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_LENGTH_FORMAT_CORRUPTED",
    "wrong hash length format";

# wrong hash key length format (3a instead of 3)
throw_oxi_exception $obj, "HASH-20-3a-key-SCALAR-4-0000-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_KEY_LENGTH_FORMAT_CORRUPTED",
    "wrong hash key length format";

# wrong hash key length (99 instead of 3)
throw_oxi_exception $obj, "HASH-20-99-key-SCALAR-4-0000-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_KEY_LENGTH_CORRUPTED",
    "wrong hash key length";

# wrong hash length (10 instead of 20)
throw_oxi_exception $obj, "HASH-10-3-key-SCALAR-4-0000-",
    "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_LENGTH_CORRUPTED",
    "wrong hash length";

1;
