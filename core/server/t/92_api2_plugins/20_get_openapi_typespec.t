#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use Scalar::Util;
use B ();

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;

# use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::API2::Plugin::Workflow::get_openapi_typespec'} = 100;



my $oxitest = OpenXPKI::Test->new;

#
# syntax checks
#
throws_ok {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Hash[size:Int,age:Float]");
} qr/unknown/i, "complain about unknown type";

throws_ok {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Array[Hash[age:Int]");
} qr/unbalanced/i, "complain about unbalanced brackets";

throws_ok {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Hash[Int,hobbies:Array]");
} qr/key/i, "complain about missing object key";

#
# Type names
#
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Hash[ s1:Str, s2:String, i1: Int, i2: Integer, n1: Num, n2: Numeric, b1: Bool, b2: Boolean, o1: Obj, o2: Object, o3: HashRef, a1: Array, a2:ArrayRef ]");
    cmp_deeply $result, {
        type => 'object',
        properties => {
            's1' => { type => 'string' },
            's2' => { type => 'string' },
            'i1' => { type => 'integer' },
            'i2' => { type => 'integer' },
            'n1' => { type => 'numeric' },
            'n2' => { type => 'numeric' },
            'b1' => { type => 'boolean' },
            'b2' => { type => 'boolean' },
            'o1' => { type => 'object' },
            'o2' => { type => 'object' },
            'o3' => { type => 'object' },
            'a1' => { type => 'array', items => {}, },
            'a2' => { type => 'array', items => {}, },
        },
    } or diag explain $result;
} "various allowed type names";

#
# Arrays
#

# without item type
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Array");
    cmp_deeply $result, {
        type => 'array',
        items => {},
    } or diag explain $result;
} "array without item type";

# with item type
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Array[Str]");
    cmp_deeply $result, {
        type => 'array',
        items => {type => 'string', }
    } or diag explain $result;
} "array with item type";

# with mixed-type items
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Array[ Str | Int ]");
    cmp_deeply $result, {
        type => 'array',
        items => {
            'oneOf' => [ { type => 'string' }, { type => 'integer' } ],
        }
    } or diag explain $result;
} "array with mixed-type items";

#
# Objects
#

# without property specification
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Hash");
    cmp_deeply $result, {
        type => 'object',
    } or diag explain $result;
} "object without property specification";

# with property specification
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Hash[ name:Str, age:Int ]");
    cmp_deeply $result, {
        type => 'object',
        properties => {
            'name' => { type => 'string' },
            'age' => { type => 'integer' },
        }
    } or diag explain $result;
} "object with property specification";

# with required properties
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "Hash[ name:Str!, age:Int ]");
    cmp_deeply $result, {
        type => 'object',
        properties => {
            'name' => { type => 'string' },
            'age' => { type => 'integer' },
        },
        required => [ 'name' ],
    } or diag explain $result;
} "object with property specification";

#
# Type parameters
#
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec => "String(minLength:5, maxLength:10)");
    cmp_deeply $result, {
        type => 'string',
        minLength => 5,
        maxLength => 10,
    } or diag explain $result;
} "type parameters";

#
# Enum
#
lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec =>
        'String(minLength:5, maxLength:10, enum:<eins,zwei \, Komma,dr \> \] ei>)'
    );
    cmp_deeply $result, {
        type => 'string',
        minLength => 5,
        maxLength => 10,
        enum => [ 'eins', 'zwei \, Komma', 'dr \> \] ei' ],
    } or diag explain $result;
} "string enum";

lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec =>
        'Array[String(minLength:5, maxLength:10, enum:<eins,zwei \, Komma,dr \> \] ei>) | Int(enum:<1,4,5>)]'
    );

    my $isnum = sub {
        my $num = shift;
        return sub {
            my $v = shift;
            # check if internal representation is numeric
            #
            my $b_obj = B::svref_2object(\$v);
            my $flags = $b_obj->FLAGS;
            my $comp_1 = ($flags & ( B::SVp_IOK | B::SVp_NOK ));
            my $comp_2 = ($flags & B::SVp_POK);
            return (0, "'$v' is represented as a string internally") unless ($comp_1 and not $comp_2);
            return (0, "expected: $num, got: $v") unless ($v == $num);
            return 1;
        }
    };

    cmp_deeply $result, {
        type => 'array',
        items => {
            'oneOf' => [
                {
                    type => 'string',
                    minLength => 5,
                    maxLength => 10,
                    enum => [ 'eins', 'zwei \, Komma', 'dr \> \] ei' ],
                },
                {
                    type => 'integer',
                    enum => [
                        code($isnum->(1)),
                        num(4),
                        num(5),
                    ]
                },
            ]
        }
    } or diag explain $result;
} "array with string and int enums";

#
# Complex nested type spec
#

lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec =>
        'Array[ Hash[ age:Int( minimum:0 ), size:Int, hobbies:Array[ Str(enum:<eins,zwei \, Komma,dr \> \] ei>) ]]]'
    );
    cmp_deeply $result, {
        type => 'array',
        items => {
            type => 'object',
            properties => {
                'age' => { type => 'integer', minimum => '0' },
                'size' => { type => 'integer' },
                'hobbies' => { type => 'array', items => { type => 'string', enum => [ 'eins', 'zwei \, Komma', 'dr \> \] ei' ] }, },
            },
        }
    } or diag explain $result;
} "complex nested type spec with whitespace everywhere";

lives_and {
    my $result = CTX('api2')->get_openapi_typespec(spec =>
        'Array[Hash[age:Int(minimum:0),size:Int!,hobbies:Array[Str(enum:<eins,zwei \, Komma,dr \> \] ei>)]]]'
    );
#    my $result = CTX('api2')->get_openapi_typespec(spec => 'Array[ Hash[ age:Int( minimum:0 ), size:Int, hobbies:Array[ Str(enum:<eins,zwei \, Komma,dr \> \] ei>) ]]]');
    cmp_deeply $result, {
        type => 'array',
        items => {
            type => 'object',
            properties => {
                'age' => { type => 'integer', minimum => '0' },
                'size' => { type => 'integer' },
                'hobbies' => { type => 'array', items => { type => 'string', enum => [ 'eins', 'zwei \, Komma', 'dr \> \] ei' ] }, },
            },
            required => [ 'size' ],
        }
    } or diag explain $result;
} "complex nested type spec with whitespace only in enum";

done_testing;
