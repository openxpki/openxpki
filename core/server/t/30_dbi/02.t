use strict;
use warnings;
use Test::More;
plan tests => 11;

diag "OpenXPKI::Server::DBI: CA setup and empty CRL\n" if $ENV{VERBOSE};

use OpenXPKI::Server::DBI;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypto::CRL;

use Data::Dumper;

ok(1);

TODO: {
    # Note: this whole test script needs refactoring to apply Better Perl Practices ;-)
    todo_skip 'See Issue #188', 10;
our $dbi;
our $token;
require 't/30_dbi/common.pl';

ok(1);

my $cert = OpenXPKI->read_file ("t/25_crypto/test-ca/cacert.pem");
$cert = OpenXPKI::Crypto::X509->new (DATA => $cert, TOKEN => $token);
my $crl = OpenXPKI->read_file ("t/25_crypto/test-ca/crl.pem");
$crl = OpenXPKI::Crypto::CRL->new (DATA => $crl, TOKEN => $token);
# FIXME: Crashes OpenSSL parsing later - what is this for?
#$cert->set_header_attribute (PKI_REALM => "I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA",
#                             CA        => "test-ca");
$crl->set_header_attribute (PKI_REALM => "I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA",
                            CA        => "test-ca");

ok($cert and $crl);

# insert CA certificate
$cert->set_status ("ISSUED");
ok($cert);

# write self-signed root cert to DB

my %hash = $cert->to_db_hash();
$hash{'ISSUER_IDENTIFIER'} = 'dummy';
$hash{PKI_REALM} = '';
my $serial = $dbi->get_new_serial(
    TABLE => 'CERTIFICATE',
);
$hash{'CERTIFICATE_SERIAL'} = $serial;

$dbi->insert (TABLE => "CERTIFICATE", HASH => \%hash);

my $attribute_serial = 1;
$dbi->insert(
    TABLE => 'CERTIFICATE_ATTRIBUTES',
    HASH => 
    {
	IDENTIFIER               => $cert->get_identifier(),
	ATTRIBUTE_KEY            => 'dummy key',
	ATTRIBUTE_VALUE          => 'dummy value',
	ATTRIBUTE_SERIAL         => $attribute_serial++,
    });

$dbi->commit();
ok(1);
if ($ENV{DEBUG}) {
    diag "Certificate with identifier " . $cert->get_identifier()
        . " inserted.\n";
} 

# insert aliases

$dbi->insert(
    TABLE => 'ALIASES',
    HASH  => {
        IDENTIFIER => $cert->get_identifier(),
        PKI_REALM  => 'I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA',
        ALIAS      => 'test-ca',
        GROUP_ID => 'test-ca',
    },
);
$dbi->commit();
ok(1);

# insert first CRL

my %db_hash = $crl->to_db_hash();
$db_hash{PKI_REALM} = 'I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA';
$db_hash{ISSUER_IDENTIFIER} = $cert->get_identifier();
$serial = $dbi->get_new_serial(
        TABLE => 'CRL',
);
$db_hash{'CRL_SERIAL'} = $serial;
$dbi->insert (TABLE => "CRL", HASH => \%db_hash);
$dbi->commit();

ok(1);

}
1;
