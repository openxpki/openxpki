#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempfile );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 31;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows CryptoLayer )],
    #log_level => 'debug',
);

my $serializer = OpenXPKI::Serialization::Simple->new();
srand();
my $subject = sprintf "nicetest-%01x.openxpki.test", rand(10000000);
my $sAlternateSubject = sprintf "nicetest-%01x.openxpki.test", rand(10000000);

my %cert_subject_parts = (
    hostname => $subject,
    hostname2 => [ "www2.$subject" , "www3.$subject" ],
    port => 8080,
);

my %cert_info = (
    requestor_gname => "Andreas",
    requestor_name => "Anders",
    requestor_email => "andreas.anders\@mycompany.local",
);

note "CSR Subject: $subject\n";

my $user = 'user';
$oxitest->set_user('ca-one' => $user);

my $wf;
lives_ok {
    $wf = $oxitest->create_workflow('certificate_signing_request_v2' => {
        cert_profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
        cert_subject_style => "00_basic_style",
    }, 1);
} "Create workflow";

$wf->state_is("SETUP_REQUEST_TYPE");
$wf->execute('csr_provide_server_key_params' => {
    key_alg => "rsa",
    enc_alg => 'aes256',
    key_gen_params => $serializer->serialize( { KEY_LENGTH => 2048 } ),
    password_type => 'client',
    csr_type => 'pkcs10'
});

$wf->state_is("ENTER_KEY_PASSWORD");
$wf->execute('csr_ask_client_password' => {
    _password => "m4#bDf7m3abd",
});

$wf->state_is("ENTER_SUBJECT");
$wf->execute('csr_edit_subject' => {
    cert_subject_parts => $serializer->serialize( \%cert_subject_parts )
});

$wf->state_is("ENTER_SAN");
$wf->execute('csr_edit_san' => {
    cert_san_parts => $serializer->serialize( {  } )
});

$wf->state_is("ENTER_CERT_INFO");
$wf->execute('csr_edit_cert_info' => {
    cert_info => $serializer->serialize( \%cert_info )
});

$wf->state_is('SUBJECT_COMPLETE');

# Nicetest FQDNs should not validate so we need a policy expcetion request
# (on rare cases the responsible router might return a valid address, so we check)
my $result = $oxitest->api2_command('get_workflow_info' => { id => $wf->id });
my $actions = $result->{state}->{option};
my $intermediate_state;
if (grep { /^csr_enter_policy_violation_comment$/ } @$actions) {
    note "Test FQDNs do not resolve - handling policy violation";
    $wf->execute('csr_enter_policy_violation_comment' => { policy_comment => 'This is just a test' } );
    $intermediate_state ='PENDING_POLICY_VIOLATION';
}
else {
    note "For whatever reason test FQDNs do resolve - submitting request";
    $wf->execute('csr_submit' );
    $intermediate_state ='PENDING';
}

$wf->state_is($intermediate_state);

# ACL Test - should not be allowed to user
$wf->execute_fails('csr_put_request_on_hold' => { onhold_comment => 'No Comment'}, qr/csr_acl_can_approve/);


# set current user to: operator
$oxitest->set_user('ca-one' => 'raop');


$wf->execute('csr_put_request_on_hold' => { onhold_comment => 'No Comment'} );
$wf->state_is("ONHOLD");

$wf->execute('csr_put_request_on_hold' => { onhold_comment => 'Still on hold'} );
$wf->state_is("ONHOLD");

$wf->execute('csr_release_on_hold');
$wf->state_is($intermediate_state);

$wf->execute('csr_approve_csr');

$wf->state_is('SUCCESS');

my $info = $oxitest->api2_command('get_workflow_info' => { id => $wf->id } );
like $info->{workflow}->{context}->{cert_subject}, "/^CN=$subject:8080,.*/", 'correct certificate subject';


# set current user to: normal user
$oxitest->set_user('ca-one' => 'user');


#
# Fetch certificate via API
#
$info = $oxitest->api2_command('get_workflow_info' => { id => $wf->id } );
my $cert_id = $info->{workflow}->{context}->{cert_identifier};
note "Test certificate ID: $cert_id";

#
# Fetch private key
#
my $privkey;
lives_and {
    my $result = $oxitest->api2_command('get_private_key_for_cert' => { identifier => $cert_id, format => 'PKCS12', 'password' => 'm4#bDf7m3abd' } );
    $privkey = $result;
    isnt $privkey, "";
} "Fetch PKCS12 private key";

lives_and {
    my $exists = $oxitest->api2_command('private_key_exists_for_cert' => { identifier => $cert_id } );
    is $exists, 1;
} "confirm that private key exists";

my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
print $tmp $privkey;
close $tmp;

# test PKCS12 container
$ENV{OPENSSL_CONF} = "/dev/null"; # prevents "WARNING: can't open config file: ..."
like `openssl pkcs12 -in $tmp_name -nokeys -noout -passin pass:'m4#bDf7m3abd' 2>&1`,
    "/MAC verified OK/",
    'Test PKCS12 container via OpenSSL';

#
# cert profile
#
lives_and {
    my $result = $oxitest->api2_command('get_profile_for_cert' => { identifier => $cert_id });
    is $result, "I18N_OPENXPKI_PROFILE_TLS_SERVER";
} "query certificate profile";

#
# cert actions
#
lives_and {
    my $result = $oxitest->api2_command('get_cert_actions' => { identifier => $cert_id, role => "User" });
    cmp_deeply $result, superhashof({
        # actions are defined in config/openxpki/config.d/realm/ca-one/uicontrol/_default.yaml,
        # they must exist and "User" must be defined in their "acl" section as creator
        workflow => superbagof(
            {
                'label' => 'I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY',
                'workflow' => 'certificate_privkey_export',
            },
            {
                'label' => 'I18N_OPENXPKI_UI_CERT_ACTION_REVOKE',
                'workflow' => 'certificate_revocation_request_v2',
            },
        ),
    });
} "query actions for certificate (role 'User')";

#
# certificate owner
#
# the workflow automatically sets this to the workflow creator, which in our
# case is "user" (see session user in OpenXPKI::Test::QA::Role::WorkflowCreateCert->create_cert)
lives_and {
    is $oxitest->api2_command('is_certificate_owner' => { identifier => $cert_id, user => $user }), 1;
} "confirm correct certificate owner";

lives_and {
    isnt $oxitest->api2_command('is_certificate_owner' => { identifier => $cert_id, user => 'nerd' }), 1;
} "negate wrong certificate owner";
