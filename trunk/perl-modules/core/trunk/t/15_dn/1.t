
## SYNTAX VALIDATION
##
## This test script should only be used for syntax checks.
## Please insert here all unusual distinguished names which you know.
## Good examples are inspired from the italian signature law and
## from the globus toolkit. If you have a new special DN then send
## it to us and we include it.

use strict;
use warnings;
use Test::More;
use OpenXPKI::DN;

my %example = (
    ## normal DN
    "CN=max mustermann,OU=employee,O=university,C=de" => 
        [
         [ ["CN", "max mustermann"] ],
         [ ["OU", "employee"] ],
         [ ["O",  "university"] ],
         [ ["C",  "de"] ]
        ],
    ## Italian signature law
    "CN=name=max/birthdate=26091976,OU=unit,O=example,C=it" =>
        [
         [ ["CN", "name=max/birthdate=26091976"] ],
         [ ["OU", "unit"] ],
         [ ["O",  "example"] ],
         [ ["C",  "it"] ]
        ],
    ## mutlivalued RDN
    "CN=Max Mustermann+UID=123456,OU=unit,O=example,C=uk" =>
        [
         [
          ["CN",  "Max Mustermann"],
          ["UID", "123456"]
         ],
         [ ["OU", "unit"] ],
         [ ["O",  "example"] ],
         [ ["C",  "uk"] ]
        ],
    ## + is a normal character here
    "CN=Max Mustermann\\+uid=123456,OU=unit,O=example,C=uk" =>
        [
         [ ["CN", "Max Mustermann+uid=123456"] ],
         [ ["OU", "unit"] ],
         [ ["O",  "example"] ],
         [ ["C",  "uk"] ]
        ],
    ## globus toolkit http
    "CN=http/www.example.com,O=university,C=ar" =>
        [
         [ ["CN", "http/www.example.com"] ],
         [ ["O",  "university"] ],
         [ ["C",  "ar"] ]
        ],
    ## globus toolkit ftp
    "CN=ftp/ftp.example.com,O=university,C=ar" =>
        [
         [ ["CN", "ftp/ftp.example.com"] ],
         [ ["O",  "university"] ],
         [ ["C",  "ar"] ]
        ],
    ## DC syntax
    "CN=foo.example.com,DC=example,DC=com" =>
        [
         [ ["CN", "foo.example.com"] ],
         [ ["DC",  "example"] ],
         [ ["DC",  "com"] ]
        ],
              );

BEGIN { plan tests => 66 };

diag "SYNTAX VALIDATION\n";

foreach my $dn (keys %example)
{
    ## init object

    my $object = OpenXPKI::DN->new ($dn);
    ok(defined $object, 'OpenXPKI::DN object defined');
    is ($object->get_rfc_2253_dn(), $dn, "Could not parse RFC2253 DN");

    my @attr = $object->get_parsed();

    ## validate parsed structure

    for (my $i=0; $i < scalar @{$example{$dn}}; $i++)
    {
        ## we are at RDN level now
        for (my $k=0; $k < scalar @{$example{$dn}[$i]}; $k++)
        {
            ## we are at attribute level now
            is ($attr[$i][$k]->[0], 
		$example{$dn}[$i][$k][0], 
		"Got: $attr[$i][$k]->[0], expected $example{$dn}[$i][$k][0]");
            is ($attr[$i][$k]->[1], 
		$example{$dn}[$i][$k][1], 
		"Got: $attr[$i][$k]->[1], expected $example{$dn}[$i][$k][1]");
        }
    }
}

1;
