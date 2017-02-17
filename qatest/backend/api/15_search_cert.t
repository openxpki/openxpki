#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use File::Temp qw( tempdir );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;
use Math::BigInt;

# Project modules
use lib qw(../../lib);
use OpenXPKI::Test::More;
use TestCfg;
use OpenXPKI::Test::CertHelper;
use DbHelper;

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
$test->plan( tests => 33 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#
my $db_helper = DbHelper->new;
my $cert_helper = OpenXPKI::Test::CertHelper->new;
my $certs = $cert_helper->certs;
my $acme_root = $certs->{acme_root};

# Import test certificates
$db_helper->delete_cert_by_id($cert_helper->all_cert_ids); # just in case a previous test left some
$db_helper->insert_test_cert($certs->{$_}->db) for @{ $cert_helper->all_cert_names };

=pod

CERT_SERIAL                 Int|Str: decimal serial or hex (starting with "0x")
PKI_REALM                   Str: default is the sessions realm, _any for global search
ORDER                       Str: column to order by (default: cert_key) --> remove "CERTIFICATE."
STATUS                      Str: cert status, special status "EXPIRED"
IDENTIFIER                  Str
ISSUER_IDENTIFIER           Str
CSR_SERIAL                  Str
SUBJECT_KEY_IDENTIFIER      Str
AUTHORITY_KEY_IDENTIFIER    Str
EMAIL                       Str: Suche mit LIKE
SUBJECT                     Str: Suche mit LIKE
ISSUER_DN                   Str: Suche mit LIKE
VALID_AT                    Int: epoch

PROFILE
NOTBEFORE/NOTAFTER          Int|HashRef: with SCALAR searches "other side" of validity or pass HASH with operator
    --> HashRef with BETWEEN, LESS_THAN, GREATER_THAN used in OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates

CERT_ATTRIBUTES list of conditions to search in attributes (KEY, VALUE, OPERATOR)

LIMIT           Int: limit results
START           Int: offset for results
LAST            Bool: show only last found cert
FIRST           Bool: show only first found cert
REVERSE         Bool: Reverse ordering
ENTITY_ONLY     Bool: show only certificates issued by this ca (where CSR_SERIAL is set)


    my $query = {
        CERT_ATTRIBUTES => [{
            KEY => 'system_cert_owner',
            VALUE =>  $self->_session->param('user')->{name},
            OPERATOR => 'EQUAL'
        }],
        ORDER => 'CERTIFICATE.NOTBEFORE',
        REVERSE => 1,
    };

    $self->logger()->debug( "search query: " . Dumper $query);

    my $search_result = $self->send_command( 'search_cert', { %$query, ( LIMIT => $limit, START => $startat ) } );

=cut

# Checks if the given DB result ArrayRef contains the test certificates with
# the given names.
sub certlist_is {
    my ($list, @expected_names) = @_;
    cmp_bag $list, [
        map { superhashof({ SUBJECT_KEY_IDENTIFIER => $certs->{$_}->id }) } @expected_names
    ], "Correct result";
}

# By CERT_SERIAL and PKI_REALM
$test->runcmd_ok('search_cert', { CERT_SERIAL => $acme_root->db->{cert_key} }, "Search cert without giving PKI realm");
is scalar(@{ $test->get_msg->{PARAMS} }), 0, "Should not return any results";

$test->runcmd_ok('search_cert', { CERT_SERIAL => $acme_root->db->{cert_key}, PKI_REALM => $acme_root->db->{pki_realm} }, "Search cert by serial (decimal) and PKI realm _ANY");
certlist_is $test->get_msg->{PARAMS}, qw( acme_root );

$test->runcmd_ok('search_cert', { CERT_SERIAL => $acme_root->db->{cert_key}, PKI_REALM => "_ANY" }, "Search cert by serial (decimal) and PKI realm");
certlist_is $test->get_msg->{PARAMS}, qw( acme_root );

$test->runcmd_ok('search_cert', {
    CERT_SERIAL => Math::BigInt->new($acme_root->db->{cert_key})->as_hex,
    PKI_REALM => $acme_root->db->{pki_realm}
}, "Search cert by serial (hex) and specific PKI realm");
certlist_is $test->get_msg->{PARAMS}, qw( acme_root );

# Custom ORDER
$test->runcmd_ok('search_cert', { ORDER => "CERTIFICATE.NOTBEFORE" }, "Search and order by NOTBEFORE descending (default)");
my $last_value;
my $sort_ok = scalar(@{ $test->get_msg->{PARAMS} }) > 0; # make sure certificates are returned
while (my $cert = shift @{ $test->get_msg->{PARAMS} } and $sort_ok) {
    $sort_ok = 0 if ($last_value and $last_value < $cert->{NOTBEFORE});
    $last_value = $cert->{NOTBEFORE};
}
ok($sort_ok, "Certificates are sorted correctly");

# Custom ORDER not reversed
$test->runcmd_ok('search_cert', { ORDER => "CERTIFICATE.NOTBEFORE", REVERSE => 0 }, "Search and order by NOTBEFORE ascending");
$sort_ok = scalar(@{ $test->get_msg->{PARAMS} }) > 0; # make sure certificates are returned
while (my $cert = shift @{ $test->get_msg->{PARAMS} } and $sort_ok) {
    $sort_ok = 0 if ($last_value and $last_value > $cert->{NOTBEFORE});
    $last_value = $cert->{NOTBEFORE};
}
ok($sort_ok, "Certificates are sorted correctly");

# By STATUS: "EXPIRED"
$test->runcmd_ok('search_cert', { STATUS => "EXPIRED", PKI_REALM => "_ANY" }, "Search expired certificates");
certlist_is $test->get_msg->{PARAMS}, qw( expired_root expired_signer expired_client );

# By IDENTIFIER
$test->runcmd_ok('search_cert', { IDENTIFIER => $certs->{acme2_client}->db-> {identifier}, PKI_REALM => "_ANY" }, "Search certificates by identifier");
certlist_is $test->get_msg->{PARAMS}, qw( acme2_client );

# By ISSUER_IDENTIFIER
$test->runcmd_ok('search_cert', { ISSUER_IDENTIFIER => $acme_root->db->{issuer_identifier}, PKI_REALM => "_ANY" }, "Search certificates by issuer");
certlist_is $test->get_msg->{PARAMS}, qw( acme_root acme_signer );

# By SUBJECT_KEY_IDENTIFIER
$test->runcmd_ok('search_cert', { SUBJECT_KEY_IDENTIFIER => $acme_root->db->{subject_key_identifier}, PKI_REALM => "_ANY" }, "Search certificates by subject key id");
certlist_is $test->get_msg->{PARAMS}, qw( acme_root );

# By AUTHORITY_KEY_IDENTIFIER
$test->runcmd_ok('search_cert', { AUTHORITY_KEY_IDENTIFIER => $certs->{acme2_root}->db->{authority_key_identifier}, PKI_REALM => "_ANY" }, "Search certificates by authority key id");
certlist_is $test->get_msg->{PARAMS}, qw( acme2_root acme2_signer );

# By SUBJECT (Suche mit LIKE)
$test->runcmd_ok('search_cert', { SUBJECT => $certs->{acme2_client}->db->{subject}, PKI_REALM => "_ANY" }, "Search certificates by subject (exact match)");
certlist_is $test->get_msg->{PARAMS}, qw( acme2_client );

$test->runcmd_ok('search_cert', { SUBJECT => "*OU=ACME,DC=OpenXPKI*", PKI_REALM => "_ANY" }, "Search certificates by subject (with wildcards)");
certlist_is $test->get_msg->{PARAMS}, @{ $cert_helper->all_cert_names };

# By ISSUER_DN (Suche mit LIKE)
$test->runcmd_ok('search_cert', { ISSUER_DN => $certs->{orphan}->db->{issuer_dn}, PKI_REALM => "_ANY" }, "Search certificates by issuer DN (exact match)");
certlist_is $test->get_msg->{PARAMS}, qw( orphan );

$test->runcmd_ok('search_cert', { ISSUER_DN => "*ACME-2 Signing CA*", PKI_REALM => "_ANY" }, "Search certificates by issuer DN (with wildcards)");
certlist_is $test->get_msg->{PARAMS}, qw( acme2_client );

# By VALID_AT (Int: epoch)
$test->runcmd_ok('search_cert', { VALID_AT => $certs->{expired_root}->db->{notbefore}+10, PKI_REALM => "_ANY" }, "Search certificates by date");
certlist_is $test->get_msg->{PARAMS}, qw( expired_root expired_signer expired_client );

# By CSR_SERIAL

#
# By PROFILE
# By NOTBEFORE/NOTAFTER          Int|HashRef: with SCALAR searches "other side" of validity or pass HASH with operator
#    --> HashRef with BETWEEN, LESS_THAN, GREATER_THAN used in OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates
#
# By CERT_ATTRIBUTES list of conditions to search in attributes (KEY, VALUE, OPERATOR)

#use Data::Dumper;
#diag Dumper($test->get_msg);
#cmp_bag $test->get_msg->{PARAMS}->{imported}, [
#    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$all_ids
#], "Correctly list imported certs";


$db_helper->delete_cert_by_id($cert_helper->all_cert_ids);

$test->disconnect;
