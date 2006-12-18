use Test::More tests => 31;
use OpenXPKI::Crypto::TokenManager;
use Data::Dumper;

print STDERR "OpenXPKI::Crypto::Secret\n";

use English;

BEGIN { use_ok( 'OpenXPKI::Crypto::Secret' ) }

# use Smart::Comments;

ok(1);

eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);


my $default_token = $mgmt->get_token (TYPE      => "DEFAULT",
                                      PKI_REALM => "Test Root CA");
###########################################################################
# plain secrets
my $secret = OpenXPKI::Crypto::Secret->new();

ok(defined $secret);

ok(! $secret->is_complete());
ok(! defined $secret->get_secret());

ok($secret->set_secret('foobar'));

ok($secret->is_complete());
ok($secret->get_secret(), 'foobar');


# multi-part PINs
$secret = OpenXPKI::Crypto::Secret->new(
    {
	TYPE => 'Plain',
	PARTS => 3,
    });   # 'Plain' pin, three part

ok(! $secret->is_complete());
ok(! defined $secret->get_secret());

ok($secret->set_secret(
       {
	   PART => 1,
	   SECRET => 'foo',
       }));

ok($secret->set_secret(
       {
	   PART => 3,
	   SECRET => 'baz',
       }));
   
ok(! $secret->is_complete());
ok(! defined $secret->get_secret());

ok($secret->set_secret(
       {
	   PART => 2,
	   SECRET => 'bar',
       }));
   
ok($secret->is_complete());
ok($secret->get_secret(), 'foobarbaz');


###########################################################################
# split secrets

$secret = undef;
eval {
    $secret = OpenXPKI::Crypto::Secret->new(
	{
	    TYPE => 'Split',
	    QUORUM => 
	    {
		K => 3,
		N => 5,
	    },
            TOKEN => $default_token,
	});   # 'Split' secret, 3 out of 5 shares
};

SKIP: {
     if ($EVAL_ERROR =~ m{ I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_NOT_YET_IMPLEMENTED }xms) {
	 skip "Secret splitting not yet implemented", 11;
     }

    ok(defined $secret);
    
    my @shares = $secret->compute();
    print STDERR "Shares: " . Dumper(\@shares) . "\n" if ($ENV{DEBUG});
   
    my $created_secret = $secret->get_secret();

    print STDERR "created secret: $created_secret\n" if ($ENV{DEBUG});
 
    $recover_secret = OpenXPKI::Crypto::Secret->new(
	{
	    TYPE => 'Split',
	    QUORUM => 
	    {
		K => 3,
		N => 5,
	    },
            TOKEN => $default_token,
	});   # 'Split' secret, 3 out of 5 shares
    ok(! $recover_secret->is_complete());
    ok(! defined $recover_secret->get_secret());
    
    # share #2
    ok($recover_secret->set_secret($shares[2]));
    
    ok(! $recover_secret->is_complete());
    ok(! defined $recover_secret->get_secret());
    

    # share #4
    ok($recover_secret->set_secret($shares[4]));
    
    ok(! $recover_secret->is_complete());
    ok(! defined $recover_secret->get_secret());
    
    # share #1
    ok($recover_secret->set_secret($shares[1]));
    
    ok($recover_secret->is_complete());
    ok($recover_secret->get_secret(), $created_secret);
}
