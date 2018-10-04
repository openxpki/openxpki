#!/usr/bin/perl

use lib qw(../../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use JSON;
use MockSC;
use Crypt::CBC;
use Log::Log4perl qw(:easy);
use Digest::SHA qw(sha256_hex);
use MIME::Base64;

use Test::More tests => 12;

#Log::Log4perl->easy_init($DEBUG);


my $auth1 = 'andi.auth@mycompany.local';
my $auth2 = 'bob.builder@mycompany.local';
my $cardOwner = 'thomas.tester@mycompany.local';
my $cardOwnerName = 'Thomas Tester';

my $client = new MockSC();

$client->session();
# required to have the cardowner in the session
$client->mock_request( 'utilities', 'get_card_status', { cardID => '12345678', cardtype => 'Gemalto .NET', ChipSerial => 'chip0815' } );

$client->session()->param('aeskey', sha256_hex( '12345' ) );

$client->defaults({ cardID => '12345678', cardtype => 'Gemalto .NET', ChipSerial => 'chip0815' });

my $result = $client->mock_request( 'pinreset', 'start_pinreset', {
    'email1' => $auth1,
    'email2' => $auth2,
} );

my $wf_id = $result->{'unblock_wfID'};
like($result->{'unblock_wfID'},qr/^\d+$/, 'Got workflow id' );
is($result->{'auth1_ldap_mail'}, $auth1);

#is($result->{error}, undef);

my $pinclient = new MockSC();

$ENV{'REMOTE_USER'} = $auth1;
$pinclient->client()->auth()->{stack} = 'User';
$result = $pinclient->mock_request( 'getauthcode', 'getauthcode', { 'id' => $wf_id });
is ($result->{foruser}, $cardOwnerName);
ok($result->{code});

my $code1 = $result->{code};

diag('Got first auth code: ' . $code1);


# wrong user
$ENV{'REMOTE_USER'} = $cardOwner;
$result = $pinclient->mock_request( 'getauthcode', 'getauthcode', { 'id' => $wf_id });

is($result->{errors}->[0], 'I18N_OPENXPKI_CLIENT_GETAUTHCODE_ERROR_EXECUTING_SCPU_GENERATE_ACTIVATION_CODE');
ok($result->{error});


$ENV{'REMOTE_USER'} = $auth2;
$result = $pinclient->mock_request( 'getauthcode', 'getauthcode', { 'id' => $wf_id });
is ($result->{foruser}, $cardOwnerName);
ok($result->{code});
my $code2 = $result->{code};
diag('Got second auth code: ' . $code2);

$pinclient = undef;

$result = $client->mock_request( 'pinreset', 'pinreset_verify', {
    'unblock_wfID' => $wf_id,
    'activationCode1' => $code1,
    'activationCode2' => $code2,
} );

is($result->{'wfstate'}, 'CAN_WRITE_PIN');
ok($result->{'exec'});

my $command;
eval {
    my $cipher = Crypt::CBC->new( -key => pack('H*', $client->session()->param('aeskey')), -cipher => 'Crypt::OpenSSL::AES' );
    $command = $cipher->decrypt( decode_base64($result->{'exec'}) );
};
if ($EVAL_ERROR) {
    diag($EVAL_ERROR);
}

like($command, qr/ResetPIN;CardSerial=12345678;PUK=\w+;/, 'command string ok');

$result = $client->mock_request( 'pinreset', 'pinreset_confirm', {
    'unblock_wfID' => $wf_id,
    'Result' => 'SUCCESS',
} );

is($result->{'wfstate'}, 'SUCCESS');

