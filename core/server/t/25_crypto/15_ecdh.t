use strict;
use warnings;
use utf8;
use Test::More;
use English;
use Crypt::PK::ECC;
use OpenXPKI::Crypt::ECDH;
plan tests => 4;

use_ok "OpenXPKI::Crypt::ECDH";

my $alice_key = Crypt::PK::ECC->new();
$alice_key->generate_key('secp256r1');

my $bob = OpenXPKI::Crypt::ECDH->new( $alice_key->export_key_pem('public') );
my $bob_key = $bob->key();


my $bob_pem = $bob_key->export_key_pem('public');

my $alice = OpenXPKI::Crypt::ECDH->new( pub_key => Crypt::PK::ECC->new(\$bob_pem), key => $alice_key );
ok ($bob->secret());
ok ($alice->secret());
is ($bob->secret(), $alice->secret() );

