use Test;
BEGIN { plan tests => 8 };

print STDERR "OpenXPKI::Crypto::VolatileVault\n";

use English;

use OpenXPKI::Crypto::VolatileVault;
# use Smart::Comments;

our $cache;
eval `cat t/25_crypto/common.pl`;

ok(1);

my $mgmt = OpenXPKI::Crypto::TokenManager->new ();
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "DEFAULT", 
    PKI_REALM => "Test Root CA");
ok (1);

my $vault = OpenXPKI::Crypto::VolatileVault->new(
    {
	TOKEN => $token,
    });

my $secret = 'abc123' x 10;

my $public = $vault->encrypt(
    {
	DATA => $secret,
	ENCODING => 'base64-oneline',
    });

ok($public);

ok($vault->can_decrypt($public));

my $tmp;
$tmp = $vault->decrypt($public);

ok($secret, $tmp);

###########################################################################

# try to decrypt it with another vault instance
my $othervault = OpenXPKI::Crypto::VolatileVault->new(
    {
	TOKEN => $token,
    });

ok(! $othervault->can_decrypt($public));

eval {
    $tmp = $othervault->decrypt($public);
};
if ($EVAL_ERROR) {
    ok($EVAL_ERROR, 'I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_DECRYPT_INVALID_VAULT_INSTANCE');
} else {
    ok(0);
}
