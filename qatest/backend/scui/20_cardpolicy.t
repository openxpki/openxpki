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

use Test::More tests => 7;

#Log::Log4perl->easy_init($DEBUG);


my $auth1 = 'andi.auth@mycompany.local';
my $auth2 = 'bob.builder@mycompany.local';
my $cardOwner = 'thomas.tester@mycompany.local';

my $client = new MockSC();

# required to have the cardowner in the session
$client->mock_request( 'utilities', 'get_card_status', { cardID => '12345678', cardtype => 'Gemalto .NET', ChipSerial => 'chip0815' } );

$client->session()->param('aeskey', sha256_hex( '12345' ) );

$client->defaults({ cardID => '12345678', cardtype => 'Gemalto .NET', ChipSerial => 'chip0815' });

my $result = $client->mock_request( 'changecardpolicy', 'get_card_policy' );

my $wf_id = $result->{'changecardpolicy_wfID'};
like( $wf_id,qr/^\d+$/, 'Got workflow id' ); 

ok($result->{'exec'});

my $command;
eval {    
    my $cipher = Crypt::CBC->new( -key => pack('H*', $client->session()->param('aeskey')), -cipher => 'Crypt::OpenSSL::AES' );                   
    $command = $cipher->decrypt( decode_base64($result->{'exec'}) );
};
if ($EVAL_ERROR) {
    diag($EVAL_ERROR);
}

like($command, qr{SetPINPolicy;CardSerial=12345678;PUK=\w+;B64Data=BQX/Bf//AQABAQEA//8=});

# Fail workflow
$result = $client->mock_request( 'changecardpolicy', 'confirm_policy_change', 
    { 'Result' => 'Failed', 'Reason' => 'Failed in Test Case', changecardpolicy_wfID => $wf_id } );

is($result->{'state'}, 'FAILURE'); 

# same for disable
$result = $client->mock_request( 'changecardpolicy', 'get_card_policy', { disable => 'true' } );
$wf_id = $result->{'changecardpolicy_wfID'};

ok($result->{'exec'});

$command = '';
eval {    
    my $cipher = Crypt::CBC->new( -key => pack('H*', $client->session()->param('aeskey')), -cipher => 'Crypt::OpenSSL::AES' );                   
    $command = $cipher->decrypt( decode_base64($result->{'exec'}) );
};
if ($EVAL_ERROR) {
    diag($EVAL_ERROR);
}

like($command, qr{SetPINPolicy;CardSerial=12345678;PUK=\w+;B64Data=BQX/Bf//AQABAAEA//8=});

$result = $client->mock_request( 'changecardpolicy', 'confirm_policy_change', { changecardpolicy_wfID => $wf_id, Result => 'SUCCESS' } );

is($result->{'state'}, 'SUCCESS');