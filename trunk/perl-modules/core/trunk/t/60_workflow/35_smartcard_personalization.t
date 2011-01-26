use strict;
use warnings;
use Carp;
use English;

package OpenXPKI::Tests::More::SmartcardPersonalization;
use base qw( OpenXPKI::Tests::More );

package main;
use Data::Dumper;

my $realm = 'User TEST CA';
my $instancedir = '';
my $socketfile  = $instancedir . '/var/openxpki/openxpki.socket';
my $wf_type     = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V3';
my %act_test = (
    user => {
	name   => 'CHANGEME',
	role   => 'User',
	token  => 'CHANGEME',
    },
    websso => {
	    name => 'CHANGEME',
    },
);

# DATA FOR USING IN TEST ON DCA04
$act_test{websso} = { name => 'martin.bartosch@db.com' };

my @certs;

#push @certs, ...

map { s/\s//g; } @certs;

# DATA FOR USING IN MY VM TEST GUEST
$act_test{user}->{name}  = undef;
$act_test{user}->{token} = 'gem2_094F88ECF273ABE6';

#my $test =  OpenXPKI::Tests::More::SmartcardPersonalization->new()
my $test =  OpenXPKI::Tests::More->new( { socketfile => $socketfile, realm => $realm } )
    or die "Error creating new test instance: $@";

$test->plan(tests => 4);

$test->diag("Smartcard Personalization workflow\n");

$test->diag('##################################################');
$test->diag('# Walk through a single workflow session:');
$test->diag('# - fresh card that is ready for personalization');
$test->diag('# - (pin unknown, will need puk)');
$test->diag('##################################################');

# Note: if anything in this section fails, just die immediately
# because continuing with the other tests then makes no sense.

$test->connect_ok( 
    user => $act_test{user}->{name}, 
    password => $act_test{user}->{role}, 
    ) 
    or die "Need session to continue: $@";


$test->create_ok( 
    $wf_type,
    { 
	token_id => $act_test{user}->{token},
	login_id => $act_test{websso}->{name},
	certs_on_card => join(';', @certs),
	#certs_on_card => join(';', ()),
    } )
    or die "Unable to create workflow: ", $test->dump();

# $test->state_is( 'PUK_TO_INSTALL' ) or die "Incorrect state: $@";

# my $newpuk = $test->param('_newpuk');

# $test->execute_ok('scpers_fetch_puk', {});
# my $oldpuk = $test->param('_puk');
# $test->diag('Old puk: ', $oldpuk, ', newpuk: ', $newpuk);


# complete sample response of token plugin: Result=SUCCESS&CardType=RSA_2.0&TokenID=1A01384505062626&CachedPIN=CD%2bpsIT9vkdyiw9CqRMOGloOqTFT3rGqJXxF4S%2fQBQSbZabGo5uqTuazdX%2bSWTqiRx2X0g%3d%3d&PBPos=100&KeyID=861646715c835ee950bce670908ea190985d7a65&PKCS10Request=MIIBazCB2QIBADAwMS4wCQYDVQQuEwJkYjAKBgNVBC4TA2NvbTAVBgNVBAMTDkdvcmRvbiBTaHVtd2F5MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCxZMvsE0Nl5IAM1VnXPopi%2f7MOcRiBfOrWyd6CEZVPAnZrP6ef7xiZof%2fcSbJJWHmB1vdw%2b1H%2bCwPlXExK3pJK5FEZ%2fxerQciGOKcvTwImOzMCiVLlFwmiRCfShgss9YMiJz4x3%2b0D36NoWQigOuaz593N2u9OpqxkWU%2fikpNoYwIDAQABoAAwCQYFKw4DAh0FAAOBgQAt0%2fINjPMX35rfXePf%2bPAFp26OtpBKko97T%2fXePbw2HfQZtFTa4OIF6LH%2bfg%2fQJyyp5yRzHfgLKRoFvCCbPXAziCwM6NFfXJ4yQwmltoImTdp6GBQaZM2s%2bFwhA%2f1yrsgkSEGX1I5u6ww%2bOkzJnZitrvOz0cjIZY69eVT6tHZxKQ%3d%3d

#$test->dump;

# $test->execute_ok(
#    'scpers_fetch_puk',
#    {
#    }) or die "Could not execute activity: $@";


# $test->param_is('_puk', '0' x 48 );

# $test->dump;

# $test->execute_ok('scpers_puk_write_ok', {});

$test->state_is( 'NEED_NON_ESCROW_CSR' ) or die "Incorrect state: $@";

$test->execute_ok(
    'scpers_fetch_puk',
    {
    }) or die "Could not execute activity: $@";


# $test->param_is('_puk', '000000000000000000000000000000000000000000000000');

$test->dump;

my $pkcs10 = 'MIIBazCB2QIBADAwMS4wCQYDVQQuEwJkYjAKBgNVBC4TA2NvbTAVBgNVBAMTDkdvcmRvbiBTaHVtd2F5MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCxZMvsE0Nl5IAM1VnXPopi/7MOcRiBfOrWyd6CEZVPAnZrP6ef7xiZof/cSbJJWHmB1vdw+1H+CwPlXExK3pJK5FEZ/xerQciGOKcvTwImOzMCiVLlFwmiRCfShgss9YMiJz4x3+0D36NoWQigOuaz593N2u9OpqxkWU/ikpNoYwIDAQABoAAwCQYFKw4DAh0FAAOBgQAt0/INjPMX35rfXePf+PAFp26OtpBKko97T/XePbw2HfQZtFTa4OIF6LH+fg/QJyyp5yRzHfgLKRoFvCCbPXAziCwM6NFfXJ4yQwmltoImTdp6GBQaZM2s+FwhA/1yrsgkSEGX1I5u6ww+OkzJnZitrvOz0cjIZY69eVT6tHZxKQ==';

# split line into 76 character long chunks
$pkcs10 = join("\n", ($pkcs10 =~ m[.{1,64}]g));

# add header
$pkcs10 = "-----BEGIN CERTIFICATE REQUEST-----\n"
    . $pkcs10 . "\n"
    . "-----END CERTIFICATE REQUEST-----";

$test->execute_ok(
    'scpers_post_non_escrow_csr',
    {
	pkcs10 => $pkcs10,
	keyid => 'n/a',
    }) or die "Could not execute activity: $@";

$test->dump;

while ($test->state() =~ m{ \A (?:CERT_TO_INSTALL|PKCS12_TO_INSTALL) }xms) {
    my $state = $test->state();

    if ($state eq 'CERT_TO_INSTALL') {
	$test->diag('X.509 certificate to install');
	$test->diag($test->param('certificate'));
	
	$test->ok($test->param('certificate') =~ m{ \A -----BEGIN }xms);
	$test->execute_ok('scpers_cert_inst_ok');
    }
    if ($state eq 'PKCS12_TO_INSTALL') {
	$test->diag('PKCS#12 to install');
	$test->diag($test->param('_pkcs12base64'));
	
	$test->param_is('_p12password', 'OpenXPKI');
	$test->ok($test->param('_pkcs12base64') ne '');
    }
    $test->execute_ok(
	'scpers_cert_inst_ok',
	{
	}) or die "Could not execute activity: $@";
    
    $test->dump;
    
}



# LOGOUT
$test->disconnect();

