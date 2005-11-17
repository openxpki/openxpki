
## OUTPUT VALIDATION
##
## Here we can check the different output functions. This is necessary
## to be able to maintain a maximum compatibility with OpenSSLs
## proprietary format for the option -subj of the commands ca and req.

use strict;
use warnings;
use Test;
use OpenXPKI::DN;

my %example = (
    ## normal DN
    "CN=max mustermann,OU=employee,O=university,C=de" => 
        [
         "CN=max mustermann,OU=employee,O=university,C=de",  ## RFC 2253
         "C=de,O=university,OU=employee,CN=max mustermann",  ## X.500
         "/C=de/O=university/OU=employee/CN=max mustermann", ## OpenSSL
        ],
    ## Italian signature law
    "CN=name=max/birthdate=26091976,OU=unit,O=example,C=it" =>
        [
         "CN=name=max/birthdate=26091976,OU=unit,O=example,C=it",
         "C=it,O=example,OU=unit,CN=name=max/birthdate=26091976",
         "/C=it/O=example/OU=unit/CN=name=max\\/birthdate=26091976",
        ],
    ## mutlivalued RDN
    "CN=Max Mustermann+UID=123456,OU=unit,O=example,C=uk" =>
        [
         "CN=Max Mustermann+UID=123456,OU=unit,O=example,C=uk",
         "C=uk,O=example,OU=unit,CN=Max Mustermann+UID=123456",
         "/C=uk/O=example/OU=unit/CN=Max Mustermann+UID=123456",
        ],
    ## + is a normal character here
    "CN=Max Mustermann\\+uid=123456,OU=unit,O=example,C=uk" =>
        [
         "CN=Max Mustermann\\+uid=123456,OU=unit,O=example,C=uk",
         "C=uk,O=example,OU=unit,CN=Max Mustermann\\+uid=123456",
         "/C=uk/O=example/OU=unit/CN=Max Mustermann\\+uid=123456",
        ],
    ## globus toolkit http
    "CN=http/www.example.com,O=university,C=ar" =>
        [
         "CN=http/www.example.com,O=university,C=ar",
         "C=ar,O=university,CN=http/www.example.com",
         "/C=ar/O=university/CN=http\\/www.example.com",
        ],
    ## globus toolkit ftp
    "CN=ftp/ftp.example.com,O=university,C=ar" =>
        [
         "CN=ftp/ftp.example.com,O=university,C=ar",
         "C=ar,O=university,CN=ftp/ftp.example.com",
         "/C=ar/O=university/CN=ftp\\/ftp.example.com",
        ],
    ## DC syntax
    "CN=foo.example.com,DC=example,DC=com" =>
        [
         "CN=foo.example.com,DC=example,DC=com",
         "DC=com,DC=example,CN=foo.example.com",
         "/DC=com/DC=example/CN=foo.example.com",
        ],
              );

BEGIN { plan tests => 42 };

print STDERR "OUTPUT VALIDATION\n";

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
    ok ($object->get_rfc_2253_dn(), $example{$dn}[0]);
    ok ($object->get_x500_dn(), $example{$dn}[1]);
    ok ($object->get_openssl_dn(), $example{$dn}[2]);
    my %dn_hash = $object->get_hashed_content();
    foreach my $key (keys %dn_hash)
    {
        ok (0) if ($key =~ /(ARRAY|HASH)/);
        foreach my $value (@{$dn_hash{$key}})
        {
            ok (0) if ($value =~ /(ARRAY|HASH)/);
        }
    }
    ok(1);
}

1;
