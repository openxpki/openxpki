
use strict;
use warnings;
use Test;
# use Smart::Comments;

BEGIN { plan tests => 16 };

print STDERR "OpenXPKI::Crypto::Command: Create a CA\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Profile::Certificate;

our $cache;
our $basedir;
require 't/25_crypto/common.pl';

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0);
ok (1);


foreach my $ca_name (qw(INTERNAL_CA_1 INTERNAL_CA_2)) {

    my $cn = $ca_name;
    $cn =~ s{ INTERNAL_ }{}xms;

    my $dir = lc($cn);
    $dir =~ s{ _ }{}xms;


    ## parameter checks for get_token

    my $token = $mgmt->get_token (TYPE => "CA", 
				  NAME => $ca_name, 
				  PKI_REALM => "Test Root CA",
	);
    ok (1);
    
    ## create CA RSA key (use passwd from token.xml)
    ## FIXME: CA key is *unencrypted*?
    my $key = $token->command ({COMMAND    => "create_key",
				TYPE       => "RSA",
				KEY_LENGTH => "1024",
				ENC_ALG    => "aes256"});
    ok (1);
    print STDERR "CA RSA: $key\n" if ($ENV{DEBUG});
    
    ## create CA CSR
    my $csr = $token->command ({COMMAND => "create_pkcs10",
				SUBJECT => "cn=$cn,dc=OpenXPKI,dc=info"});
    ok (1);
    print STDERR "CA CSR: $csr\n" if ($ENV{DEBUG});
    
    ## create profile
    my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
	CONFIG    => $cache,
	PKI_REALM => "Test Root CA",
	CA        => $ca_name,
	TYPE      => "CA");
    $profile->set_serial(1);
    ok(1);

    ### profile: $profile
    
    ## create CA cert
    my $cert = $token->command ({COMMAND => "create_cert",
				 PROFILE => $profile,
				 CSR     => $csr});
    ok (1);
    print STDERR "CA cert: $cert\n" if ($ENV{DEBUG});

    ## check that the CA is ready for further tests
    if (not -e "$basedir/$dir/cakey.pem")
    {
	ok(0);
	print STDERR "Missing CA key\n";
    } else {
	ok(1);
    }
    if (not -e "$basedir/$dir/cacert.pem")
    {
	ok(0);
	print STDERR "Missing CA cert\n";
    } else {
	ok(1);
    }
}

1;
