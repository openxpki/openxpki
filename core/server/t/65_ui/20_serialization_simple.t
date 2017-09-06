use strict;
use warnings;
use Test::More tests => 32;
use English;
use utf8; # otherwise the utf8 tests does not work
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

BEGIN { use_ok( 'OpenXPKI::Serialization::Simple' ); }

print STDERR "OpenXPKI::Serialization::Simple\n" if $ENV{VERBOSE};

my $ref = OpenXPKI::Serialization::Simple->new ();
ok($ref, 'Default seperator');

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

# hashes are not sorted, so this will fail if JSON module reorders the hashes on serialization!
#my $expected_serialization = qq(OXJSF1:{"FOOTER":["OK","Abort"],"HEADER":["Testheader"],"LIST":[{"Undefined":null,"Serial":[10,12],"Name":["John Doe"]},{"Name":["Jane Doe"],"Serial":[11,13]}],"UNDEFINED":null});
#is($text, $expected_serialization, 'Serialization outputs expected serialization');

like($text, "/OXJSF1:{.*}/" );

my $res = $ref->deserialize($text);
ok($res, 'Deserialization produced a result');

is_deeply($res, $hash, "Data structure survived (de)serialization");

## check that undef really works
ok (! defined $hash->{'UNDEFINED'}, 'undefined hash');
ok (! defined $res->{'UNDEFINED'}, 'undefined ref');
ok (! defined $hash->{'LIST'}->[0]->{'UNDEFINED'}, 'undefined hash/array');
ok (! defined $res->{'LIST'}->[0]->{'UNDEFINED'}, 'undefined res/array');

## testing utf-8 encoding

$hash = { "cn"    => ["Иван Петров"] };
$text = $ref->serialize ($hash, 'utf8 serialization');

my $expected_serialization = qq(OXJSF1:{"cn":["Иван Петров"]});
## downgrade from utf8 to byte level
#$expected_serialization = pack ("C*", unpack ("U0C*", $expected_serialization));
is($text, $expected_serialization, 'UTF8 serialization produces expected result');

$res = $ref->deserialize($text);
ok($res, 'UTF8 serialized text deserialized');
is_deeply($res, $hash, "Data structure survived (de)serialization");

##########################################################################
# more in-depth testing of deserialization
my $serialized_data = "";
my $exception = "";

# unknown data type ("MYTYPE")
$serialized_data = "MYTYPE-3-abc-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "unknown data type");
$exception = undef;
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_DATA_TYPE_NOT_SUPPORTED",
    "correct error message for unknown data type") || diag $EVAL_ERROR;


# wrong scalar format (length format corrupted)
$serialized_data = "SCALAR-3a-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong scalar format");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_SCALAR_FORMAT_CORRUPTED",
    "correct error message for wrong scalar format") || diag $EVAL_ERROR;

# wrong scalar length (10 instead of 3)
$serialized_data = "SCALAR-10-abc-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong scalar length");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_SCALAR_DENOTED_LENGTH_TOO_LONG",
    "correct error message for wrong scalar length") || diag $EVAL_ERROR;

# wrong array format (length format corrupted)
$serialized_data = "ARRAY-xxx-0-SCALAR-3-ccc-1-SCALAR-5-abcde-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong array length format");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_LENGTH_FORMAT_CORRUPTED",
    "correct error message for wrong array length format") || diag $EVAL_ERROR;

# wrong array format (element position format corrupted)
$serialized_data = "ARRAY-32-xxx-SCALAR-3-ccc-1-SCALAR-5-abcde-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong array element position format");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_ELEMENT_POSITION_FORMAT_CORRUPTED",
    "correct error message for wrong array element position format") || diag $EVAL_ERROR;

# wrong array length (10 instead of 32)
$serialized_data = "ARRAY-10-0-SCALAR-3-ccc-1-SCALAR-5-abcde-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong array length");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_LENGTH_CORRUPTED",
    "correct error message for wrong array length") || diag $EVAL_ERROR;

# wrong hash format (length format corrupted)
$serialized_data = "HASH-xyz-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong hash length format");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_LENGTH_FORMAT_CORRUPTED",
    "correct error message for wrong hash length format") || diag $EVAL_ERROR;

# wrong hash key length format (3a instead of 3)
$serialized_data = "HASH-20-3a-key-SCALAR-4-0000-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong hash key length format");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_KEY_LENGTH_FORMAT_CORRUPTED",
    "correct error message for wrong hash key length format") || diag $EVAL_ERROR;

# wrong hash key length (99 instead of 3)
$serialized_data = "HASH-20-99-key-SCALAR-4-0000-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong hash key length");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_KEY_LENGTH_CORRUPTED",
    "correct error message for wrong hash key length") || diag $EVAL_ERROR;

# wrong hash length (10 instead of 20)
$serialized_data = "HASH-10-3-key-SCALAR-4-0000-";
eval {
    $res = $ref->deserialize($serialized_data);
};
ok($EVAL_ERROR, "wrong hash length");
$exception = OpenXPKI::Exception->caught();
ok(defined $exception && $exception->message eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_LENGTH_CORRUPTED",
    "correct error message for wrong hash length") || diag $EVAL_ERROR;

# wrong undef format
#$serialized_data = "UNxDEF-";
#eval {
#    $res = $ref->deserialize($serialized_data);
#};
#ok($EVAL_ERROR, "wrong undef format");
#$exception = OpenXPKI::Exception->caught();
#ok(defined $exception && $exception->message() eq "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_UNDEF_FORMAT_CORRUPTED",
#    "correct error message for wrong undef format") || diag $EVAL_ERROR;

##########################################################################

1;
