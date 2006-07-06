use strict;
use warnings;
use Test;
BEGIN { plan tests => 8 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::Command::symmectric_cipher\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new ();
ok (1);


my $default_token = $mgmt->get_token (TYPE      => "DEFAULT",
                                      PKI_REALM => "Test Root CA");


my $cleartext = "abc123" x 10;
my $ciphertext;

############################################################################

$ciphertext = $default_token->command(
    {
	COMMAND => 'symmetric_cipher',
        DATA    => $cleartext,
	MODE    => 'ENCRYPT',
	ENC_ALG => 'aes-256-cbc',
	PASSWD  => 'swordfish',
    });

ok($ciphertext);

my $tmp;
$tmp = $default_token->command(
    {
	COMMAND => 'symmetric_cipher',
        DATA    => $ciphertext,
	MODE    => 'DECRYPT',
	ENC_ALG => 'aes-256-cbc',
	PASSWD  => 'swordfish',
    });

ok($tmp);
ok($tmp, $cleartext);


###########################################################################
# now try the same with explicit keys

$ciphertext = $default_token->command(
    {
	COMMAND => 'symmetric_cipher',
        DATA    => $cleartext,
	MODE    => 'ENCRYPT',
	ENC_ALG => 'aes-256-cbc',
	IV      => 'C0CAFEBABE47',
	KEY     => '03DEADBEEF89',
    });

ok($ciphertext);

$tmp = $default_token->command(
    {
	COMMAND => 'symmetric_cipher',
        DATA    => $ciphertext,
	MODE    => 'DECRYPT',
	ENC_ALG => 'aes-256-cbc',
	IV      => 'C0CAFEBABE47',
	KEY     => '03DEADBEEF89',
    });

ok($tmp);
ok($tmp, $cleartext);

