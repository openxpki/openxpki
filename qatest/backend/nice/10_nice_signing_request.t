#!/usr/bin/perl
#
# 045_activity_tools.t
#
# Tests misc workflow tools like WFObject, etc.
#
# Note: these tests are non-destructive. They create their own instance
# of the tools workflow, which is exclusively for such test purposes.

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use File::Temp qw( tempfile );

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use Test::More;
use Test::Deep;
use OpenXPKI::Test::More;
use TestCfg;
use utf8;

our %cfg = ();
my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg{instance}{socketfile},
    realm      => $cfg{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 29 );

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{password},
) or die "Error - connect failed: $@";

my $serializer = OpenXPKI::Serialization::Simple->new();
srand();
my $sSubject = sprintf "nicetest-%01x.openxpki.test", rand(10000000);
my $sAlternateSubject = sprintf "nicetest-%01x.openxpki.test", rand(10000000);

my %cert_subject_parts = (
	hostname => $sSubject,
	hostname2 => [ "www2.$sSubject" , "www3.$sSubject" ],
	port => 8080,
);

my %cert_info = (
    requestor_gname => "Andreas",
    requestor_name => "Anders",
    requestor_email => "andreas.anders\@mycompany.local",
);

my %cert_subject_alt_name_parts = (
);

note "CSR Subject: $sSubject\n";

$test->create_ok( 'certificate_signing_request_v2' , {
    cert_profile => $cfg{csr}{profile},
    cert_subject_style => "00_basic_style",
}, 'Create Issue Test Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SETUP_REQUEST_TYPE');

$test->execute_ok( 'csr_provide_server_key_params', {
    key_alg => "rsa",
    enc_alg => 'aes256',
    key_gen_params => $serializer->serialize( { KEY_LENGTH => 2048 } ),
    password_type => 'client',
    csr_type => 'pkcs10'
});

$test->state_is('ENTER_KEY_PASSWORD');
$test->execute_ok( 'csr_ask_client_password', {
    _password => "m4#bDf7m3abd",
});

$test->state_is('ENTER_SUBJECT');

$test->execute_ok( 'csr_edit_subject', {
    cert_subject_parts => $serializer->serialize( \%cert_subject_parts )
});

$test->state_is('ENTER_SAN');
$test->execute_ok( 'csr_edit_san', {
    cert_san_parts => $serializer->serialize( { %cert_subject_alt_name_parts } )
});

$test->state_is('ENTER_CERT_INFO');
$test->execute_ok( 'csr_edit_cert_info', {
    cert_info => $serializer->serialize( \%cert_info )
});

$test->state_is('SUBJECT_COMPLETE');

# Nicetest FQDNs should not validate so we need a policy expcetion request
# (on rare cases the responsible router might return a valid address, so we check)
my $msg = $test->get_client->send_receive_command_msg('get_workflow_info', { ID => $test->get_wfid });
my $actions = $msg->{PARAMS}->{STATE}->{option};
my $intermediate_state;
if (grep { /^csr_enter_policy_violation_comment$/ } @$actions) {
    note "Test FQDNs do not resolve - handling policy violation";
    $test->execute_ok( 'csr_enter_policy_violation_comment', { policy_comment => 'This is just a test' } );
    $intermediate_state ='PENDING_POLICY_VIOLATION';
}
else {
    note "For whatever reason test FQDNs do resolve - submitting request";
    $test->execute_ok( 'csr_submit' );
    $intermediate_state ='PENDING';
}
$test->state_is($intermediate_state);

# ACL Test - should not be allowed to user
$test->execute_nok( 'csr_put_request_on_hold', { onhold_comment => 'No Comment'}, 'Disallow on hold to user' );

$test->disconnect();

# Re-login with Operator for approval
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

$test->execute_ok( 'csr_put_request_on_hold', { onhold_comment => 'No Comment'} );
$test->state_is('ONHOLD');

$test->execute_ok( 'csr_put_request_on_hold', { onhold_comment => 'Still on hold'} );
$test->state_is('ONHOLD');

$test->execute_ok( 'csr_release_on_hold' );
$test->state_is($intermediate_state);

$test->execute_ok( 'csr_approve_csr' );
$test->state_is('SUCCESS');

$test->param_like( 'cert_subject', "/^CN=$sSubject:8080,.*/" , 'Certificate Subject');

$test->disconnect();

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{password},
) or die "Error - connect failed: $@";

#
# Fetch certificate via API
#
my $cert_id = $test->param( 'cert_identifier' );
note "Test certificate ID: $cert_id";

#
# Fetch private key
#
$test->runcmd('get_private_key_for_cert', { IDENTIFIER => $cert_id, FORMAT => 'PKCS12', 'PASSWORD' => 'm4#bDf7m3abd' });
$test->ok ( $test->get_msg()->{PARAMS}->{PRIVATE_KEY} ne '', 'Fetch PKCS12');

my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
print $tmp $test->get_msg()->{PARAMS}->{PRIVATE_KEY};
close $tmp;

$test->disconnect();

$test->like( `openssl pkcs12 -in $tmp_name -nokeys -noout -passin pass:'m4#bDf7m3abd' 2>&1`, "/MAC verified OK/", 'Test PKCS12' );

open(CERT, ">$cfg{instance}{buffer}");
print CERT $serializer->serialize({ cert_identifier => $cert_id  });
close CERT;
