
use strict;
use warnings;
use Test;
use English;
# use Smart::Comments;

BEGIN { plan tests => 24 };

print STDERR "OpenXPKI::Crypto::Command: Create a CA\n";

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
    $OpenXPKI::Debug::LEVEL{'OpenXPKI::XML::Cache'} = 0;
    $OpenXPKI::Debug::LEVEL{'OpenXPKI::XML::Config'} = 0;
}

use OpenXPKI qw( read_file );
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Profile::Certificate;

our $cache;
our $basedir;
require 't/25_crypto/common.pl';

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);


foreach my $ca_id (qw(INTERNAL_CA_1 INTERNAL_CA_2)) {

    my $cn = $ca_id;
    $cn =~ s{ INTERNAL_ }{}xms;

    my $dir = lc($cn);
    $dir =~ s{ _ }{}xms;


    ## parameter checks for get_token

    my $token = $mgmt->get_token (TYPE => "CA", 
				  ID => $ca_id, 
				  PKI_REALM => "Test Root CA",
                                  CERTIFICATE => 'dummy',
	);
    ok (1);
    
    ## create CA RSA key (use passwd from token.xml)
    my $key = $token->command ({COMMAND    => "create_key",
				TYPE       => "RSA",
                                PARAMETERS => {
				    KEY_LENGTH => "1024",
				    ENC_ALG    => "aes256"}});
    ok (1);
    print STDERR "CA RSA: $key\n" if ($ENV{DEBUG});

    # key is present
    ok($key =~ /^-----BEGIN.*PRIVATE KEY-----/);

    # key is encrypted
    ok($key =~ /^-----BEGIN ENCRYPTED PRIVATE KEY-----/);
    

    ## create CA CSR
    my $csr;
    eval
    {
        $csr = $token->command ({COMMAND => "create_pkcs10",
                                 SUBJECT => "cn=$cn,dc=OpenXPKI,dc=info"});
    };
    if ($EVAL_ERROR)
    {
        print STDERR "Exception: ${EVAL_ERROR}\n";
        ok(0);
        exit 1;
    } else {
        ok (1);
    }
    print STDERR "CA CSR: $csr\n" if ($ENV{DEBUG});
    
    ## create profile
    my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
	CONFIG    => $cache,
	PKI_REALM => "Test Root CA",
	CA        => $ca_id,
	TYPE      => "SELFSIGNEDCA");
    $profile->set_serial(1);
    ok(1);

    ### profile: $profile
    
    ## create CA cert
    my $cert = $token->command ({COMMAND => "create_cert",
				 PROFILE => $profile,
				 CSR     => $csr});
    ok (1);
    print STDERR "CA cert: $cert\n" if ($ENV{DEBUG});

    # FIXME: create_cert should not write the text representation of the
    # cert to the file specified in the configuration
    OpenXPKI->write_file (
	FILENAME => "$basedir/$dir/cacert.pem", 
	CONTENT  => $cert,
	FORCE    => 1,
	);

    ## check that the CA is ready for further tests
    if (not -e "$basedir/$dir/cakey.pem")
    {
	ok(0);
	print STDERR "Missing CA key ($basedir/$dir/cakey.pem).\n";
    } else {
	ok(1);
    }

    my $content = OpenXPKI->read_file("$basedir/$dir/cakey.pem" );
    ok($content =~ /^-----BEGIN.*PRIVATE KEY-----/);
    ok($content =~ /^-----BEGIN ENCRYPTED PRIVATE KEY-----/);

    if (not -e "$basedir/$dir/cacert.pem")
    {
	ok(0);
	print STDERR "Missing CA cert\n";
    } else {
	ok(1);
    }
}

1;
