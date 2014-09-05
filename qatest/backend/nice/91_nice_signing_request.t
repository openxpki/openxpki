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

use lib qw(
  /usr/lib/perl5/
  ../../lib
);

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;
use utf8;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 20 );

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";

my $serializer = OpenXPKI::Serialization::Simple->new();
srand();
my $sSubject = sprintf "nicetest-%01x.openxpki.test", rand(10000000);
my $sAlternateSubject = sprintf "nicetest-%01x.openxpki.test", rand(10000000);

my %cert_subject_parts = (
	cert_subject_hostname => $sSubject,
	cert_subject_hostname2 => [ "www2.$sSubject" , "www3.$sSubject" ],
	cert_subject_port => 8080,
);

my %cert_info = (
    requestor_gname => "Andreäs",
    requestor_name => "Andärs",
    requestor_email => "andreas.anders\@mycompany.local",
);

my %cert_subject_alt_name_parts = (
);

my %wfparam = (
	cert_role => $cfg{csr}{role},
	cert_profile => $cfg{csr}{profile},
	cert_subject_style => "00_basic_style",
	cert_subject_parts => $serializer->serialize( \%cert_subject_parts ),
	cert_subject_alt_name_parts => $serializer->serialize( { %cert_subject_alt_name_parts } ),
	cert_info => $serializer->serialize( \%cert_info ),
	csr_type => "pkcs10",
);




print "CSR Subject: $sSubject\n";

$test->create_ok( 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST' , \%wfparam, 'Create Issue Test Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SERVER_KEY_GENERATION');

# Trigger key generation
my $param_serializer = OpenXPKI::Serialization::Simple->new({SEPARATOR => "-"});

$test->execute_ok( 'I18N_OPENXPKI_WF_ACTION_GENERATE_KEY', {
	_key_type => "RSA",
    _key_gen_params => $param_serializer->serialize( { KEY_LENGTH => 2048, ENC_ALG => "aes128" } ),
    _password => "m4#bDf7m3abd" } ) or die "Error - keygen failed: $@";


$test->state_is('PENDING');

# ACL Test - should not be allowed to user
$test->execute_nok( 'I18N_OPENXPKI_WF_ACTION_CHANGE_CSR_ROLE', {  cert_role => $cfg{csr}{role}}, 'Disallow change role' );

$test->disconnect();

# Re-login with Operator for approval
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{role},
) or die "Error - connect failed: $@";

$test->execute_ok( 'I18N_OPENXPKI_WF_ACTION_CHANGE_CSR_ROLE', {  cert_role => $cfg{csr}{role}} );

$test->execute_ok( 'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR' );

$test->state_is('APPROVAL');

$test->execute_ok( 'I18N_OPENXPKI_WF_ACTION_PERSIST_CSR' );

$test->param_like( 'cert_subject', "/^CN=$sSubject:8080,.*/" , 'Certificate Subject');

$test->state_is('SUCCESS');

$test->disconnect();

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";

my $cert_identifier = $test->param( 'cert_identifier' );
my $tmpfile = "/tmp/mytest.$$";

# Try to fetch the key via API
$test->runcmd('get_cert', { IDENTIFIER => $cert_identifier, FORMAT => 'PEM' });
my $pem = $test->get_msg()->{PARAMS};
$test->like( $pem, "/^-----BEGIN CERTIFICATE-----/", 'Fetch certificate (PEM)' );

# Try DER Format
$test->runcmd('get_cert', { IDENTIFIER => $cert_identifier, FORMAT => 'DER' });

$test->ok(open(DER, ">$tmpfile"), 'Write DER');
print DER $test->get_msg()->{PARAMS};
close DER;

my $pem2 =  `openssl x509 -in $tmpfile -inform DER`;

# Clear all whitespace to compare
$pem =~ s{\s}{}gxms;
$pem2 =~ s{\s}{}gxms;
$test->is( $pem, $pem2, 'DER ?= PEM' );

$test->runcmd('get_private_key_for_cert', { IDENTIFIER => $cert_identifier, FORMAT => 'PKCS12', 'PASSWORD' => 'm4#bDf7m3abd' });
$test->ok ( $test->get_msg()->{PARAMS}->{PRIVATE_KEY} ne '', 'Fetch p12');

$test->ok(open(P12, ">$tmpfile"));
print P12 $test->get_msg()->{PARAMS}->{PRIVATE_KEY};
close P12;

$test->disconnect();

$test->like( `openssl pkcs12 -in $tmpfile -nokeys -noout -passin pass:'m4#bDf7m3abd' 2>&1`, "/MAC verified OK/", 'Test P12' );
unlink $tmpfile;

open(CERT, ">$cfg{instance}{buffer}");
print CERT $serializer->serialize({ cert_identifier => $cert_identifier  });
close CERT;

