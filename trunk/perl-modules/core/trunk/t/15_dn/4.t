
## UTF-8 VALIDATION
##
## Here we can check the different output functions. This is necessary
## to be able to maintain a maximum compatibility with OpenSSLs
## proprietary format for the option -subj of the commands ca and req.

use strict;
use warnings;
use utf8;
binmode STDERR, ":utf8";
use Test;
use OpenXPKI::DN;

my %example = (
    ## normal DN
    "CN=Иван Петрович Козлодоев,O=Организация объединённых наций,DC=UN,DC=org" =>
    {
        CN => [ "Иван Петрович Козлодоев" ],
        O  => [ "Организация объединённых наций" ],
        DC => [ "UN", "org" ]
    },
    "CN=Кузьма Ильич Дурыкин,OU=кафедра квантовой статистики и теории поля,OU=отделение экспериментальной и теоретической физики,OU=физический факультет,O=Московский государственный университет им. М.В.Ломоносова,C=ru" =>
    {
        CN => [ "Кузьма Ильич Дурыкин" ],
        OU => [ "кафедра квантовой статистики и теории поля",
                "отделение экспериментальной и теоретической физики",
                "физический факультет" ],
        O  => [ "Московский государственный университет им. М.В.Ломоносова" ],
        C  => [ "ru" ]
    },
    "CN=Mäxchen Müller,O=Humboldt-Universität zu Berlin,C=DE" =>
    {
        CN => [ "Mäxchen Müller" ],
        O  => [ "Humboldt-Universität zu Berlin" ]
    }
              );

BEGIN { plan tests => 18 };

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
    foreach my $key (keys %{$example{$dn}})
    {
        for (my $i=0; $i < scalar @{$example{$dn}->{$key}}; $i++)
        {
            if ($content{$key}[$i] eq $example{$dn}->{$key}->[$i])
            {
                ok(1);
            } else {
                ok(0);
                print STDERR "Calculated: ".$content{$key}[$i]."\n";
                print STDERR "Original:   ".$example{$dn}->{$key}->[$i]."\n";
            }
        }
    }
}

1;
