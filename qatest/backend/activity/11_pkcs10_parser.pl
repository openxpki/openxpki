#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use OpenXPKI::Serialization::Simple;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $test = OpenXPKI::Test::More->new({
    socketfile => '/var/openxpki/openxpki.socket',
    realm => '',
}) or die "Error creating new test instance: $@";

$test->set_verbose(0);

$test->plan( tests => 42 );

# Login to use socket
$test->connect_ok(
    user => 'raop',
    password => 'openxpki',
) or die "Error - connect failed: $@";

my $pkcs10 = `openssl req -new -nodes -keyout /dev/null -config openssl.conf -reqexts req_san 2>/dev/null`;

# Test without profile

my %wfparam = (
    cert_profile => 'acme',
    cert_subject_style => 'none',
    pkcs10 => $pkcs10,
);

$test->create_ok( 'test_pkcs10' , \%wfparam, 'Create Parser Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');

my $context = $test->get_msg()->{PARAMS}->{WORKFLOW}->{CONTEXT};
$test->is(ref $context, 'HASH');

$test->is($context->{'csr_key_alg'}, 'rsa');
$test->is($context->{'csr_key_params'}->{'key_length'}, '2048');

$test->is($context->{csr_subject}, 'DC=com,DC=Company,OU=IT,OU=Test,CN=test.me');

my $ser = OpenXPKI::Serialization::Simple->new();

my $subject = $ser->deserialize( $context->{cert_subject_parts} );

$test->is($subject->{SAN_URI}->[0], 'http://test.me/');
$test->is($subject->{SAN_IP}->[0], '127.0.0.1');
$test->is($subject->{SAN_DNS}->[0], 'test.me');
$test->is($subject->{SAN_DNS}->[1], 'also.test.me');
$test->is($subject->{SAN_EMAIL}->[0], 'me@test.me');
$test->is($subject->{CN}->[0], 'test.me');
$test->is($subject->{OU}->[0], 'IT');
$test->is($subject->{OU}->[1], 'Test');
$test->is($subject->{DC}->[0], 'com');
$test->is($subject->{DC}->[1], 'Company');

my $san = $ser->deserialize( $context->{cert_subject_alt_name} );

$test->is(scalar @{$san}, 5);

# order of keys in SAN hash is not defined, so we use map to check the array
$test->ok(map { ($_->[0] eq 'IP' &&  $_->[1] eq '127.0.0.1') ? 1 : ();  } @{$san});
$test->ok(map { ($_->[0] eq 'email' &&  $_->[1] eq 'me@test.me') ? 1 : ();  } @{$san});
$test->ok(map { ($_->[0] eq 'DNS' &&  $_->[1] eq 'also.test.me') ? 1 : ();  } @{$san});

$test->ok($context->{req_attributes}->{challengePassword}, 'SecretChallenge');

# Test with profile
%wfparam = (
    cert_profile => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    cert_subject_style => '00_basic_style',
    pkcs10 => $pkcs10,
);

$test->create_ok( 'test_pkcs10' , \%wfparam, 'Create Parser Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');

$context = $test->get_msg()->{PARAMS}->{WORKFLOW}->{CONTEXT};
$test->is(ref $context, 'HASH');

$subject = $ser->deserialize( $context->{cert_subject_parts} );

$test->is($subject->{hostname}, 'test.me');
$test->is($subject->{hostname2}->[0], 'test.me');
$test->is($subject->{hostname2}->[1], 'also.test.me');
$test->is(scalar @{$subject->{hostname2}}, 2);

$san = $ser->deserialize( $context->{cert_san_parts} );
$test->is($san->{dns}->[1], 'also.test.me');
$test->is($san->{ip}->[0], '127.0.0.1');
$test->is($san->{email}, undef);

$pkcs10 = `openssl req -new -nodes -keyout /dev/null -config openssl.conf -reqexts req_template_v1  2>/dev/null`;

%wfparam = (
    cert_profile => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    cert_subject_style => '00_basic_style',
    pkcs10 => $pkcs10,
);

$test->create_ok( 'test_pkcs10' , \%wfparam, 'Create Parser Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');

$context = $test->get_msg()->{PARAMS}->{WORKFLOW}->{CONTEXT};
$test->is(ref $context, 'HASH');

$test->is($context->{req_extensions}->{certificateTemplateName}, 'Machine');
$test->is($context->{req_extensions}->{certificateTemplate}, undef);


$pkcs10 = `openssl req -new -nodes -keyout /dev/null -config openssl.conf -reqexts req_template_v2  2>/dev/null`;

%wfparam = (
    cert_profile => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    cert_subject_style => '00_basic_style',
    pkcs10 => $pkcs10,
);

$test->create_ok( 'test_pkcs10' , \%wfparam, 'Create Parser Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');

$context = $test->get_msg()->{PARAMS}->{WORKFLOW}->{CONTEXT};
$test->is(ref $context, 'HASH');

$test->is($context->{req_extensions}->{certificateTemplateName}, undef);
$test->is($context->{req_extensions}->{certificateTemplate}->{templateID}, '1.3.6.1.4.1.311.21.8.15138236.9849362.7818410.4518060.12563386.22.5003942.7882920');

