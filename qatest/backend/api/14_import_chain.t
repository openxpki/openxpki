#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use File::Spec::Functions qw( catfile catdir splitpath rel2abs );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;

# Project modules
use lib qw(../../lib);
use TestCfg;
use OpenXPKI::Test::More;
use OpenXPKI::Test::CertHelper;
use OpenXPKI::Test::CertHelper::Database;

sub _slurp {
    my $filename = shift;
    my $basedir = catdir((splitpath(rel2abs(__FILE__)))[0,1]);
    return do { # slurp
        local $INPUT_RECORD_SEPARATOR;
        open my $fh, '<', catfile($basedir, $filename) or die "Could not open file $filename: $!";
        <$fh>;
    };
}

#
# Init client
#
our $cfg = {};
TestCfg->new->read_config_path( 'api.cfg', $cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg->{instance}{socketfile},
    realm => $cfg->{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg->{instance}{verbose});
$test->plan( tests => 18 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#
my $dbdata = OpenXPKI::Test::CertHelper::Database->new;

my @acme_list =  qw( acme_client  acme_signer  acme_root );
my @acme2_list = qw( acme2_client acme2_signer acme2_root );
my $acme_pem = [ map { $dbdata->cert($_)->data }  @acme_list ];
my $acme_ids = [ map { $dbdata->cert($_)->id }    @acme_list ];
my $acme_pem_string = join "\n", @$acme_pem;
my $acme2_pem = [ map { $dbdata->cert($_)->data } @acme2_list ];
my $acme2_ids = [ map { $dbdata->cert($_)->id }   @acme2_list ];
my $all_pem =  [ map { $dbdata->cert($_)->data }  @acme_list, @acme2_list ];
my $all_ids =  [ map { $dbdata->cert($_)->id  }   @acme_list, @acme2_list ];


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

$dbdata->delete_all;

# Array import: partly existing chain
$test->runcmd_ok('import_chain', { DATA => $dbdata->cert("acme2_root")->data, IMPORT_ROOT => 1 }, "Prepare next test by importing root certificate");
$test->runcmd_ok('import_chain', { DATA => $acme2_pem, IMPORT_ROOT => 1 }, "Array import: chain whose root cert is already in PKI");
cmp_deeply $test->get_msg->{PARAMS},
    superhashof({
        existed =>  bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } $dbdata->cert("acme2_root")->id),
        imported => bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } ($dbdata->cert("acme2_signer")->id, $dbdata->cert("acme2_client")->id) ),
    }),
    "List certs as imported and existing";

$dbdata->delete_all;

# Array import: two chains
$test->runcmd_ok('import_chain', { DATA => $all_pem, IMPORT_ROOT => 1 }, "Array import: two chains");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$all_ids
], "List imported certs";

$dbdata->delete_all;

# PEM block import: Chain with root cert (IMPORT_ROOT = 1)
$test->runcmd_ok('import_chain', { DATA => $acme_pem_string, IMPORT_ROOT => 1 }, "String import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$acme_ids
], "List imported certs";

$dbdata->delete_all;

# PKCS7 import
$test->runcmd_ok('import_chain', { DATA => $dbdata->acme1_pkcs7, IMPORT_ROOT => 1 }, "PKCS7 import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$acme_ids
], "List imported certs";

$dbdata->delete_all;

$test->disconnect;
