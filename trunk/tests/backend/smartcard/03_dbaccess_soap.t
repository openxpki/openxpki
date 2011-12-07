#!/usr/bin/perl
#
# 03_cert_revoke.t - tests for soap-based dbaccess interface
#
#
# SETUP:
#
# To run this, you need to do the following in advance:
#
# - Generate CSR for TLS Client certificate
#
#	mkdir -p ca
#	openssl req -new -nodes -keyout ca/tls-client.key -out ca/tls-client.csr -newkey rsa:2048
#
# - Get a TLS Client certificate
# - Download new PEM to ca/tls-client.pem
# - Download chain to ca/tls-chain.pem

use strict;
use warnings;

use lib qw(     /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
    /usr/local/lib/perl5/site_perl/5.8.8
    /usr/local/lib/perl5/site_perl
    ../../lib
);
use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use Test::More;

use TestCfg;
use SOAP::Lite;

my $dirname = dirname($0);

our @cfgpath = ( $dirname . '/../../../config/tests/backend/smartcard', $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '03_dbaccess_soap.cfg', \%cfg, @cfgpath );

# Check for missing config params
foreach my $ent ( qw(
		core:test_ids core:soap_proxy_uri
		certs:client_cert_file
		certs:client_key_file
		certs:trusted_ca_certs_dir
) ) {
	my ($a, $b) = split(/:/, $ent, 2);
	if ( not $cfg{$a}{$b} ) {
		die "Config missing param '$b' for section '$a'";
	}
}

my @test_ids = split(/\s*[,;]\s*/, $cfg{core}{test_ids}) ;

$ENV{http_proxy} = "";
$ENV{https_proxy} = "";

$ENV{HTTPS_CA_DIR} = $cfg{certs}{trusted_ca_certs_dir};

if ($cfg{core}{use_client_authentication}) {
	$ENV{HTTPS_CERT_FILE} = $cfg{certs}{client_cert_file};
	$ENV{HTTPS_KEY_FILE} = $cfg{certs}{client_key_file};
}

diag("SOAP URI: " . $cfg{core}{soap_uri});
diag("SOAP Proxy: " . $cfg{core}{soap_proxy_uri});

my %params = ();
if ( $cfg{core}{soap_uri} ) {
	$params{uri} = $cfg{core}{soap_uri};
}
if ( $cfg{core}{soap_proxy_uri} ) {
	$params{proxy} = $cfg{core}{soap_proxy_uri};
}
my $server = SOAP::Lite->new( %params );
if ( not $server ) {
	die "Error creating new SOAP::Lite instance: $@";
}

plan tests => 10;

is($server->GetSmartcardOwner($cfg{test1}{token})->result, $cfg{test1}{owner}, 'GetSmartcardOwner() with known token ['. $cfg{test1}{token} . ']');
is($server->GetSmartcardOwner($cfg{test2}{token})->result, $cfg{test2}{owner}, 'GetSmartcardOwner() with unknown user [' . $cfg{test2}{token} . ']');
is($server->GetSmartcardOwner($cfg{test3}{token})->result, $cfg{test3}{owner}, 'GetSmartcardOwner() with unknown token [' . $cfg{test3}{token} . ']');

is($server->GetSmartcardStatus($cfg{test4}{token})->result, $cfg{test4}{status}, 'GetSmartcardStatus() with known token [' . $cfg{test4}{token} . ']');
is($server->GetSmartcardStatus($cfg{test5}{token})->result, $cfg{test5}{status}, 'GetSmartcardStatus() with known token [' . $cfg{test5}{token} . ']');
is($server->GetSmartcardStatus($cfg{test6}{token})->result, $cfg{test6}{status}, 'GetSmartcardStatus() with unknown token [' . $cfg{test6}{token}. ']');
is($server->GetSmartcardStatus($cfg{test7}{token})->result, $cfg{test7}{status}, 'GetSmartcardStatus() with unknown status [' . $cfg{test7}{token} . ']');

my @eFlds = sort split(/,\s*/, $cfg{test8}{fields});
#my @gFlds = sort ($server->GetUserDataFields()->result);
my @gFlds = ();
my $result = $server->GetUserDataFields()->result;
if ( ref($result ) eq 'ARRAY' ) {
	@gFlds = sort @{ $result };
}
is_deeply(\@gFlds,\@eFlds, 'GetUserDataFields()');
#diag("gFlds: " . join(', ', @gFlds));
#diag("eFlds: " . join(', ', @eFlds));

is($server->GetUserData($cfg{test9}{user}, $cfg{test9}{attr})->result, $cfg{test9}{cn}, 'GetUserData() [' . $cfg{test9}{user} . ']');
is($server->GetUserData($cfg{test10}{user}, $cfg{test10}{attr})->result, $cfg{test10}{cn}, 'GetUserData() [' . $cfg{test10}{user} . ']');

