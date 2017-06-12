#!/usr/bin/perl

use lib qw(../../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use JSON;
use MockSC;
use Log::Log4perl qw(:easy);
use Digest::SHA qw(sha256_hex);
use Test::More;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::SC' );
}

require_ok( 'OpenXPKI::Client::SC' );


my $number_of_tests = 10;

sub makeCSR;

#Log::Log4perl->easy_init($DEBUG);

my $client = new MockSC();
 
$client->session();
# required to have the cardowner in the session
$client->mock_request( 'utilities', 'get_card_status', { cardID => '12345678', cardtype => 'Gemalto .NET', ChipSerial => 'chip0815' } );

$client->session()->param('aeskey', sha256_hex( '12345' ) );

$client->defaults({ cardID => '12345678', cardtype => 'Gemalto .NET', ChipSerial => 'chip0815' });

my $result = $client->mock_request( 'personalization','server_personalization', {} );

my $wf_id = $result->{'perso_wfID'};
like( $wf_id ,qr/^\d+$/, 'Got workflow id' );
diag('Workflow Id is ' . $wf_id);

if ( $result->{'action'} eq 'install_puk') {
    $number_of_tests++;
    $result = $client->mock_request( 'personalization','server_personalization', {
        perso_wfID => $wf_id,
        wf_action => 'install_puk',
        Result => 'SUCCESS',    
    });    
    is ($result->{'error'}, undef);
    diag ('PUK installed');
    
}

is( $result->{'wf_state'}, 'NEED_NON_ESCROW_CSR');
is( $result->{'action'}, 'prepare');
like(  $client->session_decrypt( $result->{'exec'} ), qr/ResetPIN.*NewPIN/);

$result = $client->mock_request( 'personalization','server_personalization', {
    perso_wfID => $wf_id,
    wf_action => 'prepare',
    Result => 'SUCCESS',    
});

is( $result->{'wf_state'}, 'NEED_NON_ESCROW_CSR');
is( $result->{'action'}, 'upload_csr');

while ($result->{'action'} eq 'upload_csr') {

    $number_of_tests++;
    diag('Upload CSR');
    my $pkcs10 = makeCSR();
        $result = $client->mock_request( 'personalization','server_personalization', {
        perso_wfID => $wf_id,
        wf_action => 'upload_csr',
        PKCS10Request => $pkcs10,
        KeyID => 42    
    });

    is ($result->{'error'}, undef, 'Upload ok') || die "Upload PKCS10 failed";    
}


print Dumper $result ;

# {"wf_state":"NEED_NON_ESCROW_CSR","action":"upload_csr","perso_wfID":"28159","exec":"GenerateKeyPair;CardSerial=12345678;UserPIN=pipcd1ld9x;SubjectCN=thomas.tester@mycompany.local;KeyLength=1024;"}

done_testing();

sub makeCSR {
    
    my $pkcs10 = `openssl req -new -batch -nodes -keyout /dev/null 2>/dev/null`;
    $pkcs10 =~ s/-----(BEGIN|END) CERTIFICATE REQUEST-----//g;
    $pkcs10 =~ s/\s//g;
    
    return $pkcs10;
    
    #my $cert_type = $test->param('csr_cert_type');
    #my $csr_file = "$cert_dir/$cert_type.csr"; 
    #my $key_file = "$cert_dir/$cert_type.key";
    #`openssl req -new -batch -nodes -keyout $key_file -out $csr_file 2>/dev/null`;
    
    #my $modulus = getModulus($key_file);
    #rename $csr_file, "$cert_dir/$modulus.csr"; 
    #rename $key_file, "$cert_dir/$modulus.key";     
    #return scalar read_file("$cert_dir/$modulus.csr");
}
