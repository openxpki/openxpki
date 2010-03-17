use Test;
BEGIN { plan tests => 27 };

print STDERR "OpenXPKI::Crypto::VolatileVault\n";

use English;

use OpenXPKI::Crypto::VolatileVault;
# use Smart::Comments;
use OpenXPKI::Crypto::TokenManager;

our $cache;
eval `cat t/25_crypto/common.pl`;

ok(1);

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "DEFAULT", 
    PKI_REALM => "Test Root CA");
ok (1);

my $vault = OpenXPKI::Crypto::VolatileVault->new(
    {
	TOKEN => $token,
	EXPORTABLE => 2,
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

#####
# exporting keys should work exactly twice

eval {
    $tmp = $vault->export_key();
};
# export worked 1st time
ok($EVAL_ERROR, '');

eval {
    $tmp = $vault->export_key();
};
# export worked 2nd time
ok($EVAL_ERROR, '');


# save key for later re-initialization of vault
my $key_backup = $tmp;

# third export is prohibited
eval {
    $tmp = $vault->export_key($public);
};
ok($EVAL_ERROR, 'I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_EXPORT_KEY_DENIED');


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
ok($EVAL_ERROR, 'I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_DECRYPT_INVALID_VAULT_INSTANCE');


# exporting keys should be prohibited by default
eval {
    $tmp = $othervault->export_key();
};
ok($EVAL_ERROR, 'I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_EXPORT_KEY_DENIED');



###########################################################################


# try to decrypt it with reinstantiated vault instance
my $reused_vault = OpenXPKI::Crypto::VolatileVault->new(
    {
	TOKEN => $token,
	KEY   => $key_backup->{KEY},
	IV    => $key_backup->{IV},
	EXPORTABLE => -1,
    });

ok($reused_vault->can_decrypt($public));

$tmp = undef;
eval {
    $tmp = $reused_vault->decrypt($public);
};
ok($EVAL_ERROR, '');
ok($secret, $tmp);

# exporting keys should now be allowed
$tmp = undef;
eval {
    $tmp = $reused_vault->export_key();
};
ok($EVAL_ERROR, '');
ok($key_backup->{KEY}, $tmp->{KEY});
ok($key_backup->{IV}, $tmp->{IV});


# exporting keys should now be allowed
$tmp = undef;
eval {
    $tmp = $reused_vault->export_key();
};
ok($EVAL_ERROR, '');
ok($key_backup->{KEY}, $tmp->{KEY});
ok($key_backup->{IV}, $tmp->{IV});


# exporting keys should now be allowed
$tmp = undef;
eval {
    $tmp = $reused_vault->export_key();
};
ok($EVAL_ERROR, '');
ok($key_backup->{KEY}, $tmp->{KEY});
ok($key_backup->{IV}, $tmp->{IV});


# lock vault
$reused_vault->lock_vault();

# exporting keys should now be disallowed
$tmp = undef;
eval {
    $tmp = $reused_vault->export_key();
};
ok($EVAL_ERROR, 'I18N_OPENXPKI_CRYPTO_VOLATILEVAULT_EXPORT_KEY_DENIED');

#####
# check if key identifier can be queried
ok(length($reused_vault->get_key_id()), 8);
ok(length($reused_vault->get_key_id( { LONG => 1 })) > 20);

