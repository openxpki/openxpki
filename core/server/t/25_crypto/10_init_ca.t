
use strict;
use warnings;
use Test::More tests => 5;
use English;
# use Smart::Comments;

diag "OpenXPKI::Crypto::Command: Create a CA\n" if $ENV{VERBOSE};

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

use OpenXPKI qw( read_file );
use OpenXPKI::Crypto::TokenManager;

our $cacert;
our $cache;
our $basedir;


eval `cat t/25_crypto/common.pl`;

is($@, '', 'seems that init succeeded');

my $fu = OpenXPKI::FileUtils->new();

# We create the CA using OpenSSL directly
`openssl req -new -days 3650 -newkey rsa:2048 -keyout $basedir/test-ca/cakey.pem -out $basedir/test-ca/cacert.pem -x509 -subj "/CN=test-ca/DC=openxpki/DC=test" -passout pass:secret 2>&1 1>/dev/null`;

$cacert = $fu->read_file("$basedir/test-ca/cacert.pem");

ok($cacert =~ /^-----BEGIN CERTIFICATE-----/);

# Try to load the token with the certificate

my $mgmt = OpenXPKI::Crypto::TokenManager->new({'IGNORE_CHECK' => 1});
ok ($mgmt, 'Create OpenXPKI::Crypto::TokenManager instance');

TODO: {
    todo_skip 'See Issue #188', 2;
my $token = $mgmt->get_token ({
   TYPE => 'certsign',
   NAME => 'test-ca',
   CERTIFICATE => {
        DATA => $cacert,
        IDENTIFIER => 'ignored',
   }
});

ok (defined $token, 'Parameter checks for get_token');

# Check for private key 
my $cakey = $fu->read_file("$basedir/test-ca/cakey.pem");

ok($cakey =~ /^-----BEGIN RSA PRIVATE KEY-----/, 'RSA key loaded');
}

1;
