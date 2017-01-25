#!/usr/bin/perl

use strict;
use warnings;

use lib qw(../../lib);

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use File::Temp qw( tempdir );

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use Test::More;
use Test::Deep;
use TestCfg;
use TestCerts;
use CertHelper;

our %cfg = ();
my $testcfg = new TestCfg;
$testcfg->read_config_path( 'api.cfg', \%cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg{instance}{socketfile},
    realm => $cfg{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});
$test->plan( tests => 9 );

$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

# Create certificate on disk
my $dir = tempdir( CLEANUP => 1 );
my $fh;
open($fh, '>', "$dir/key.pas") or die "Error opening $dir/key.pas: $!";
print($fh 'mysecrettestpassword') or die "Error writing $dir/key.pas: $!";
close($fh) or die "Error closing $dir/key.pas: $!";

my $ch = CertHelper->new(basedir => $dir)->createcert;
my $cert_pem = do { local $/; open my $fh, '<', "$dir/crt.pem"; <$fh> }; # slurp

my $ch2 = CertHelper->new(basedir => $dir, commonName => 'test2.openxpki.org')->createcert;
my $cert_pem2 = do { local $/; open my $fh, '<', "$dir/crt.pem"; <$fh> }; # slurp

# Import certificate
$test->runcmd_ok('import_certificate', { DATA => $cert_pem, }, "Import certificate 1")
    or diag "ERROR: ".$test->error;
$test->is($test->get_msg->{PARAMS}->{IDENTIFIER}, $test->get_msg->{PARAMS}->{ISSUER_IDENTIFIER}, "Certificate is recognized as self-signed");

# Second import should fail
$test->runcmd('import_certificate', { DATA => $cert_pem, });
$test->error_is("I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_CERTIFICATE_ALREADY_EXISTS", "Fail importing same certificate twice");

# ...except if we want to update
$test->runcmd_ok('import_certificate', { DATA => $cert_pem, UPDATE => 1 }, "Import same certificate if UPDATE = 1");

# Import second certificate as "REVOKED"
$test->runcmd_ok('import_certificate', { DATA => $cert_pem2, REVOKED => 1 }, "Import certificate 2 as REVOKED")
    or diag "ERROR: ".$test->error;
$test->is($test->get_msg->{PARAMS}->{STATUS}, "REVOKED", "Certificate should be marked as REVOKED");

# Import expired cert
use File::Spec::Functions qw( catfile catdir splitpath rel2abs );
my $basedir = catdir((splitpath(rel2abs(__FILE__)))[0,1]);
my $alien_cert_pem = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $fh, '<', catfile($basedir, "acme-client-1.crt") or die "Could not open expired_cert_pem: $!";
    <$fh>;
};

$test->runcmd('import_certificate', { DATA => $alien_cert_pem  });
$test->error_is("I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER", "Import certificate with unknown issuer should fail");

$test->runcmd_ok('import_certificate', { DATA => $alien_cert_pem, FORCE_NOCHAIN => 1 }, "Forced import of certificate with unknown issuer")
    or diag "ERROR: ".$test->error;

$test->disconnect;
