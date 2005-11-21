
## UTF-8 VALIDATION
##
## Here we can check the different output functions. This is necessary
## to be able to maintain a maximum compatibility with OpenSSLs
## proprietary format for the option -subj of the commands ca and req.

use strict;
use warnings;
use utf8;
use Test;
use OpenXPKI::DN;

my %example = (
    ## normal DN
    "CN=Иван Петрович Козлодоев,OU=employee,O=university,C=de" => 
        [
         "Иван Петрович Козлодоев",  ## common name
        ],
    "CN=Mäxchen Müller,OU=employee,O=university,C=de" => 
        [
         "Mäxchen Müller",  ## common name
        ],
              );

BEGIN { plan tests => 6 };

print STDERR "UTF-8 VALIDATION\n";

foreach my $dn (keys %example)
{
    ## init object

    my $object = OpenXPKI::DN->new ($dn);
    if ($object)
    {
        ok (1);
    } else {
        ok (0);
    }
    ok ($object->get_rfc_2253_dn(), $dn);
    my %content = $object->get_hashed_content();
    ok ($content{"CN"}[0] eq $example{$dn}[0]);
}

1;
