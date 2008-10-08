use strict;
use warnings;
use Test::More;
use Encode;

plan tests => 26;

print STDERR "OpenXPKI::Crypto::X509\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::X509;
use Time::HiRes;
use DateTime;
use Data::Dumper;

# use Smart::Comments;

our $cache;
our $cacert;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "CA", 
    ID => "INTERNAL_CA_1", 
    PKI_REALM => "Test Root CA",
    CERTIFICATE => $cacert,
);
ok (1);

my $data;

###########################################################################
## load end entity certificate
$data = OpenXPKI->read_file ("$basedir/ca1/cert.pem");
ok(1);
$data = "-----BEGIN HEADER-----\n".
           "ROLE=User\n".
           "-----END HEADER-----\n".
           $data;

## init object
my $cert = OpenXPKI::Crypto::X509->new (TOKEN => $token, DATA => $data);
ok(1);

## test parser
# TODO - do we want get_parsed to return the bytes (as currently done, see
# UTF-8 encoded subject below) or a UTF8-decoded perl string with Unicode
# codepoints?
ok ($cert->get_parsed("BODY", "SUBJECT") eq "CN=John Dö,DC=OpenXPKI,DC=org");
ok ($cert->get_parsed("BODY", "KEYSIZE") == 1024);
my @key_usage = @{ $cert->get_parsed('BODY', 'EXTENSIONS', 'KEYUSAGE') };
ok (grep {$_ eq 'Non Repudiation'} @key_usage, 'Key Usage array contains Non Repudation');

my $notafter;
my $now = DateTime->now( time_zone => 'UTC' );
my $validity_duration;
my $duration_string;

$notafter = $cert->get_parsed("BODY", "NOTAFTER");
$validity_duration = $notafter - $now;
# 6 months configured validity minus a few seconds evaluates to 5 months
my $tmp = $validity_duration->in_units('months');
ok($tmp == 5 || $tmp == 6);

ok ($cert->get_parsed("HEADER", "ROLE") eq "User");

## test attribute setting
ok ($cert->set_header_attribute(GLOBAL_ID => 1234));
ok ($cert->get_parsed("HEADER", "GLOBAL_ID") == 1234);

## test conversion
ok ($cert->get_converted ("PEM"));
ok ($cert->get_converted ("DER"));
ok ($cert->get_converted ("TXT"));


###########################################################################
# validate CA certificates


$data = OpenXPKI->read_file("$basedir/ca1/cacert.pem");
ok(defined $data);

### reading CA certificate
$cert = OpenXPKI::Crypto::X509->new (
    TOKEN => $token, 
    DATA => $data,
    );
ok(defined $cert);

$notafter = $cert->get_parsed("BODY", "NOTAFTER");
$validity_duration = $notafter - $now;
# 90 days as configured in the profile is always 2 full months plus some days
$duration_string 
    = join(',', $validity_duration->in_units('years', 'months', 'days'));

ok($duration_string, "1,0,0");




$data = OpenXPKI->read_file("$basedir/ca2/cacert.pem");
ok(defined $data);

$cert = OpenXPKI::Crypto::X509->new (
    TOKEN => $token, 
    DATA => $data,
    );
ok(defined $cert);

$notafter = $cert->get_parsed("BODY", "NOTAFTER");
$validity_duration = $notafter - $now;
# 90 days as configured in the profile is always 2 full months plus some days
$duration_string 
    = join(',', $validity_duration->in_units('years', 'months', 'days'));

ok($duration_string, "2,0,0");



###########################################################################
## performance
my $items = 200;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    $cert = OpenXPKI::Crypto::X509->new (TOKEN => $token, DATA => $data);
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result certs/second (minimum: 100 per second)\n";
## ok ($result > 100);
ok($result);

## UTF-8 compatibility

my @example = (
    "CN=Иван Петрович Козлодоев,O=Организация объединённых наций,DC=UN,DC=org",
    "CN=Кузьма Ильич Дурыкин,OU=кафедра квантовой статистики и теории поля,OU=отделение экспериментальной и теоретической физики,OU=физический факультет,O=Московский государственный университет им. М.В.Ломоносова,C=ru",
    "CN=Mäxchen Müller,O=Humboldt-Universität zu Berlin,C=DE"
              );
@example = map { decode_utf8($_) } @example;

for (my $i=0; $i < scalar @example; $i++)
{
    $data = OpenXPKI->read_file ("$basedir/ca1/utf8.$i.cert.pem");
    $data = "-----BEGIN HEADER-----\n".
            "ROLE=User\n".
            "-----END HEADER-----\n".
            $data;
    $cert = OpenXPKI::Crypto::X509->new (TOKEN => $token, DATA => $data);
    if ($cert->get_parsed ("BODY", "SUBJECT") eq $example[$i])
    {
        ok(1);
    } else {
        ok(0);
        print STDERR "Original:  ".$example[$i]."\n";
        print STDERR "Generated: ".$cert->get_parsed ("BODY", "SUBJECT")."\n";
    }
}

1;
