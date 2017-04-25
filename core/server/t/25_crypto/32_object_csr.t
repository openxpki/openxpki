use strict;
use warnings;
use Test::More;
use English;
use Encode;
use utf8;

plan tests => 20;

TODO: {
    todo_skip 'See Issue #188', 20;

print STDERR "OpenXPKI::Crypto::CSR\n" if $ENV{VERBOSE};

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CSR;
use Time::HiRes;

our $cache;
our $cacert;
our $basedir;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 19 if $EVAL_ERROR;



## parameter checks for TokenManager init
my $mgmt = OpenXPKI::Crypto::TokenManager->new;
ok ($mgmt, 'Create OpenXPKI::Crypto::TokenManager instance');

my $token = $mgmt->get_token ({
   TYPE => 'certsign',
   NAME => 'test-ca',
   CERTIFICATE => {
        DATA => $cacert,
        IDENTIFIER => 'ignored',
   }
});

ok (defined $token, 'Parameter checks for get_token');


## load CSR
my $data = OpenXPKI->read_file ("$basedir/test-ca/pkcs10.pem");
ok(1);
$data = "-----BEGIN HEADER-----\n".
        "ROLE=User\n".
        "SERIAL=4321\n".
        "-----END HEADER-----\n".
        $data;

## init object
my $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
ok(1);

## test parser
is ($csr->get_parsed("BODY", "SUBJECT"), "CN=John Dö,DC=OpenXPKI,DC=org");
is ($csr->get_parsed("SUBJECT"), "CN=John Dö,DC=OpenXPKI,DC=org");
is ($csr->get_parsed("BODY", "KEYSIZE"), 1024);
is ($csr->get_parsed("HEADER", "ROLE"), "User");
is ($csr->get_serial(), 4321);

## test attribute setting
ok ($csr->set_header_attribute(GLOBAL_ID => 1234));
is ($csr->get_parsed("HEADER", "GLOBAL_ID"), 1234);

## test deep copy for client interfaces
my $ref = $csr->get_info_hash();
is (ref $ref, "HASH");
is ($ref->{BODY}->{SUBJECT}, "CN=John Dö,DC=OpenXPKI,DC=org");

## test conversion
ok ($csr->get_converted ("PEM"));
ok ($csr->get_converted ("DER"));
ok ($csr->get_converted ("TXT"));

## performance
my $items = 1000;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    eval
    {
        $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
    };
    if ($EVAL_ERROR)
    {
        if (my $exc = OpenXPKI::Exception->caught())
        {
            print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n";
        }
        else
        {
            print STDERR "unknown eval error: ${EVAL_ERROR}\n";
        }

    }
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result CSRs/second (minimum: 100 per second)\n" if $ENV{VERBOSE};
#ok ($result > 100);
ok ($result);

## UTF-8 compatibility

my @example = (
    "CN=Иван Петрович Козлодоев,O=Организация объединённых наций,DC=UN,DC=org",
    "CN=Кузьма Ильич Дурыкин,OU=кафедра квантовой статистики и теории поля,OU=отделение экспериментальной и теоретической физики,OU=физический факультет,O=Московский государственный университет им. М.В.Ломоносова,C=ru",
    "CN=Mäxchen Müller,O=Humboldt-Universität zu Berlin,C=DE"
              );
@example = map { decode_utf8($_) } @example;

for (my $i=0; $i < scalar @example; $i++)
{
    $data = OpenXPKI->read_file ("$basedir/test-ca/utf8.$i.pkcs10.pem");
    $data = "-----BEGIN HEADER-----\n".
            "ROLE=User\n".
            "SERIAL=4321\n".
            "SUBJECT=".$example[$i]."\n".
            "-----END HEADER-----\n".
            $data;
    $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
    if ($csr->get_parsed ("BODY", "SUBJECT") eq $example[$i])
    {
        ok(1);
    } else {
        ok(0);
        print STDERR "Original:  ".$example[$i]."\n";
        print STDERR "Generated: ".$csr->get_parsed ("BODY", "SUBJECT")."\n";
    }
    if ($csr->get_parsed ("HEADER", "SUBJECT") eq $example[$i])
    {
        ok(1);
    } else {
        ok(0);
        print STDERR "Original:  ".$example[$i]."\n";
        print STDERR "Generated: ".$csr->get_parsed ("HEADER", "SUBJECT")."\n";
    }
}

}
}
1;
