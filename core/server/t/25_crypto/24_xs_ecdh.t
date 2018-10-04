use strict;
use warnings;
use Digest::SHA qw (sha256_hex sha512_hex);
use Test::More;
use Test::Exception;
use English;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($OFF);

plan tests => 12;

use_ok 'OpenXPKI::Crypto::Backend::OpenSSL::ECDH';

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $eckey1 = '-----BEGIN EC PRIVATE KEY-----
MHQCAQEEIIyT2LytbkJG288QS6maBzoTbBUwv0JtIcUontMEaew8oAcGBSuBBAAK
oUQDQgAENVxl1lCA9wzW+wGGWwOGnHJvM8oT8NhSF4f3hdEWSVkI+01RGjOdBVBd
ea8CDwKQsjurVgFAn4Sg1GiAr+2A3g==
-----END EC PRIVATE KEY-----
';

my $eckey1_pub = '-----BEGIN PUBLIC KEY-----
MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAENVxl1lCA9wzW+wGGWwOGnHJvM8oT8NhS
F4f3hdEWSVkI+01RGjOdBVBdea8CDwKQsjurVgFAn4Sg1GiAr+2A3g==
-----END PUBLIC KEY-----
';

my $eckey2 = '-----BEGIN EC PRIVATE KEY-----
MHQCAQEEIIRLWxAHEfXj2aFNf/aHFtYHr2LKBCLkEWH3ydo4TYjsoAcGBSuBBAAK
oUQDQgAEYKa0NBxqkQYkzsaJDrVTJY0VsmWFSBMk10T+5VRyXKFcMs18IBvLaPay
lPl00RDy6ibRcH/rRWECJU0+m85jnQ==
-----END EC PRIVATE KEY-----
';

my $eckey2_pub = '-----BEGIN PUBLIC KEY-----
MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEYKa0NBxqkQYkzsaJDrVTJY0VsmWFSBMk
10T+5VRyXKFcMs18IBvLaPaylPl00RDy6ibRcH/rRWECJU0+m85jnQ==
-----END PUBLIC KEY-----
';

my $empty_key='-----BEGIN PUBLIC KEY-----
-----END PUBLIC KEY-----
';

 my $key_sha256_hex =  'f82aaa273832b0bd10cdfa903bf3fd8f91bfdbb93ba7166b05c0d2ebe32509ec';


#require_ok( 'OpenXPKI::Crypto::Backend::OpenSSL::ECDH );

#test public key extraction
my $pub = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ec_pub_key($eckey1);

ok ($pub eq $eckey1_pub, 'Extract public EC key');

my $puberr = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ec_pub_key("RANDOM INPUT");

ok ($puberr eq $empty_key, 'Extract public EC key error check');

dies_ok(sub { $puberr = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ec_pub_key("") }, "get_ec_pub_key() with empty string parameter should die" );

dies_ok(sub { $puberr = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ec_pub_key() }, "get_ec_pub_key() without parameters should die" );

#Test get ecdhkey

my $ecdhkey1 =  OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ecdh_key( $eckey1_pub , $eckey2 );

ok (sha256_hex($ecdhkey1->{ECDHKey}) eq  $key_sha256_hex, 'generate ECDH session key');

dies_ok(sub { OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ecdh_key() }, "get_ecdh_key() without parameters should die" );

dies_ok(sub { OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ecdh_key("") }, "get_ecdh_key() with empty string parameter should die" );

#test new key generation withan invalid NID
dies_ok(sub {OpenXPKI::Crypto::Backend::OpenSSL::ECDH::new_ec_keypair(1) }, "get_ecdh_key() without parameter '1' should die");

dies_ok(sub {OpenXPKI::Crypto::Backend::OpenSSL::ECDH::new_ec_keypair('foo') }, "get_ecdh_key() with string as parameter should die");

#test new keypair and simulate a full keyexchange with the 2nd key beeing generated in the exchange

my $testKeyPair1 ;
my $testKeyPair2 ;
my $testKeyPair1Pub;
my $testEcdhKey1;
my $testEcdhKey2;

eval{
    $testKeyPair1 = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::new_ec_keypair(716);
    $testKeyPair1Pub = OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ec_pub_key($testKeyPair1);
    $testEcdhKey1 =  OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ecdh_key( $testKeyPair1Pub , $testKeyPair2 );
    $testEcdhKey2 =  OpenXPKI::Crypto::Backend::OpenSSL::ECDH::get_ecdh_key( $testEcdhKey1->{'PEMECPubKey'} , $testKeyPair1 );
};

is($@ ,'', "Execute a full key exchange!");

ok (sha256_hex($testEcdhKey1->{ECDHKey}) eq  sha256_hex($testEcdhKey2->{ECDHKey}), 'compare ECDH session keys');

# diag("here's what went wrong");
# done_testing();

1;
