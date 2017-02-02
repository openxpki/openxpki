#!/usr/bin/perl

use strict;
use warnings;

use lib qw(../../lib);

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use File::Spec::Functions qw( catfile catdir splitpath rel2abs );
use File::Temp qw( tempdir );

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use Test::More;
use Test::Deep;
use TestCfg;
use TestCerts;
use DbHelper;

sub _slurp {
    my $filename = shift;
    my $basedir = catdir((splitpath(rel2abs(__FILE__)))[0,1]);
    return do { # slurp
        local $INPUT_RECORD_SEPARATOR;
        open my $fh, '<', catfile($basedir, $filename) or die "Could not open file $filename: $!";
        <$fh>;
    };
}

our %cfg = ();
my $testcfg = new TestCfg;
$testcfg->read_config_path( 'api.cfg', \%cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg{instance}{socketfile},
    realm => $cfg{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});
$test->plan( tests => 18 );

$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

# Create certificate on disk
my $dir = tempdir( CLEANUP => 1 );
my $db_helper = DbHelper->new;

my $certs = {
    acme_root => {
        pem => _slurp("test-acme-root.crt"),
        id => "39:D5:86:02:69:BC:E1:3D:7A:25:88:A9:B9:CD:F5:EB:DE:6F:91:7B",
    },
    acme_signer => {
        pem => _slurp("test-acme-signer.crt"),
        id => "DA:1B:CD:D2:00:A9:71:82:05:E7:79:FC:A3:AD:10:5D:8F:39:1B:AC",
    },
    acme2_root => {
        pem => _slurp("test-acme2-root.crt"),
        id => "C6:17:6E:AC:2E:7F:3C:9B:B0:AB:83:B6:5A:C2:F0:14:6C:A9:A4:4A",
    },
    acme2_signer => {
        pem => _slurp("test-acme2-signer.crt"),
        id => "1A:60:18:E5:10:2E:D9:FB:D2:A5:7C:76:0C:EA:5A:F7:36:71:05:BB",
    },
    acme2_client => {
        pem => _slurp("test-acme2-client.crt"),
        id => "BA:DD:07:40:71:7C:20:40:31:07:EE:E9:F6:2B:5A:A5:C2:93:C5:59",
    },
};
my $acme2_pkcs7 = _slurp("test-acme2.p7b");

my @acme_list =  qw( acme_signer acme_root );
my @acme2_list = qw( acme2_client acme2_signer acme2_root );
my $acme_pem = [ map { $certs->{$_}->{pem} }  @acme_list ];
my $acme_ids = [ map { $certs->{$_}->{id} }   @acme_list ];
my $acme_pem_string = sprintf "%s\n%s", @$acme_pem;
my $acme2_pem = [ map { $certs->{$_}->{pem} } @acme2_list ];
my $acme2_ids = [ map { $certs->{$_}->{id} }  @acme2_list ];
my $all_pem =  [ map { $certs->{$_}->{pem} }  @acme_list, @acme2_list ];
my $all_ids =  [ map { $certs->{$_}->{id}  }  @acme_list, @acme2_list ];


# Array import: Try chain with root cert (should fail)
$test->runcmd_ok('import_chain', { DATA => $acme_pem }, "Array import: chain with root cert");
like $test->get_msg->{PARAMS}->{failed}->[0]->{error},
    qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER/,
    "Return error message";
is scalar @{ $test->get_msg->{PARAMS}->{imported} }, 0, "No certs should have been imported";

# Array import: Chain with root cert (IMPORT_ROOT = 1)
$test->runcmd_ok('import_chain', { DATA => $acme_pem, IMPORT_ROOT => 1 }, "Array import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$acme_ids
], "List imported certs";

# Array import: Same chain again (should recognize existing certs)
$test->runcmd_ok('import_chain', { DATA => $acme_pem, IMPORT_ROOT => 1 }, "Array import: same chain again");
cmp_bag $test->get_msg->{PARAMS}->{existed}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$acme_ids
], "List certs as already existing";
is scalar @{ $test->get_msg->{PARAMS}->{imported} }, 0, "No certs should have been imported";

$db_helper->delete_certificate($acme_ids);

# Array import: partly existing chain
$test->runcmd_ok('import_chain', { DATA => $certs->{acme2_root}->{pem}, IMPORT_ROOT => 1 }, "Prepare next test by importing root certificate");
$test->runcmd_ok('import_chain', { DATA => $acme2_pem, IMPORT_ROOT => 1 }, "Array import: chain whose root cert is already in PKI");
cmp_deeply $test->get_msg->{PARAMS},
    superhashof({
        existed =>  bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } $certs->{acme2_root}->{id}),
        imported => bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } ($certs->{acme2_signer}->{id}, $certs->{acme2_client}->{id}) ),
    }),
    "List certs as imported and existing";

$db_helper->delete_certificate($acme2_ids);

# Array import: two chains
$test->runcmd_ok('import_chain', { DATA => $all_pem, IMPORT_ROOT => 1 }, "Array import: two chains");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$all_ids
], "List imported certs";

$db_helper->delete_certificate($all_ids);

# PEM block import: Chain with root cert (IMPORT_ROOT = 1)
$test->runcmd_ok('import_chain', { DATA => $acme_pem_string, IMPORT_ROOT => 1 }, "String import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$acme_ids
], "List imported certs";

$db_helper->delete_certificate($acme_ids);

# PKCS7 import
$test->runcmd_ok('import_chain', { DATA => $acme2_pkcs7, IMPORT_ROOT => 1 }, "PKCS7 import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$acme2_ids
], "List imported certs";

$db_helper->delete_certificate($acme2_ids);


$test->disconnect;
