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
use Data::UUID;

# Project modules
use lib qw(../../lib);
use TestCfg;
use OpenXPKI::Test::More;
use OpenXPKI::Test::CertHelper;
use OpenXPKI::Test::CertHelper::Database;

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
$test->plan( tests => 44 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#

# Import test certificates
my $dbdata = OpenXPKI::Test::CertHelper->via_database;

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
# the given internal test certificate names.
sub search_cert_ok {
    my ($message, $conditions, @expected_names) = @_;

    $test->runcmd_ok('search_cert', $conditions, "Search cert $message");

    cmp_bag $test->get_msg->{PARAMS}, [
        map { superhashof({ SUBJECT_KEY_IDENTIFIER => $dbdata->cert($_)->id }) } @expected_names
    ], "Correct result";
}

$test->runcmd_ok('search_cert', {
    CERT_SERIAL => $dbdata->cert("acme_root")->db->{cert_key}
}, "Search cert without giving PKI realm");
is scalar(@{ $test->get_msg->{PARAMS} }), 0, "Should not return any results";

search_cert_ok "by serial (decimal) and PKI realm _ANY", {
    CERT_SERIAL => $dbdata->cert("acme_root")->db->{cert_key},
    PKI_REALM => $dbdata->cert("acme_root")->db->{pki_realm}
}, qw( acme_root );

search_cert_ok "by serial (decimal) and PKI realm", {
    CERT_SERIAL => $dbdata->cert("acme_root")->db->{cert_key},
    PKI_REALM => "_ANY"
}, qw( acme_root );

search_cert_ok "by serial (hex) and specific PKI realm", {
    CERT_SERIAL => Math::BigInt->new($dbdata->cert("acme_root")->db->{cert_key})->as_hex,
    PKI_REALM => $dbdata->cert("acme_root")->db->{pki_realm}
}, qw( acme_root );

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

search_cert_ok "by expired status", {
    STATUS => "EXPIRED",
    PKI_REALM => "_ANY"
}, qw( expired_root expired_signer expired_client );

search_cert_ok "by identifier", {
    IDENTIFIER => $dbdata->cert("acme2_client")->db->{identifier},
    PKI_REALM => "_ANY"
}, qw( acme2_client );

search_cert_ok "by issuer", {
    ISSUER_IDENTIFIER => $dbdata->cert("acme_root")->db->{issuer_identifier},
    PKI_REALM => "_ANY"
}, qw( acme_root acme_signer );

search_cert_ok "by subject key id", {
    SUBJECT_KEY_IDENTIFIER => $dbdata->cert("acme_root")->db->{subject_key_identifier},
    PKI_REALM => "_ANY"
}, qw( acme_root );

search_cert_ok "by authority key id", {
    AUTHORITY_KEY_IDENTIFIER => $dbdata->cert("acme2_root")->db->{authority_key_identifier},
    PKI_REALM => "_ANY"
}, qw( acme2_root acme2_signer );

search_cert_ok "by subject (exact match)", {
    SUBJECT => $dbdata->cert("acme2_client")->db->{subject},
    PKI_REALM => "_ANY"
}, qw( acme2_client );

search_cert_ok "by subject (with wildcards)", {
    SUBJECT => "*OU=ACME,DC=OpenXPKI*",
    PKI_REALM => "_ANY"
}, @{ $dbdata->all_cert_names };

search_cert_ok "by issuer DN (exact match)", {
    ISSUER_DN => $dbdata->cert("orphan")->db->{issuer_dn},
    PKI_REALM => "_ANY"
}, qw( orphan );

search_cert_ok "by issuer DN (with wildcards)", {
    ISSUER_DN => "*ACME-2 Signing CA*",
    PKI_REALM => "_ANY"
}, qw( acme2_client );

search_cert_ok "by validity date", {
    VALID_AT => $dbdata->cert("expired_root")->db->{notbefore} + 100,
    PKI_REALM => "_ANY"
}, qw( expired_root expired_signer expired_client );

# By CSR serial
my $uuid = Data::UUID->new->create_str;
my $cert_info = OpenXPKI::Test::CertHelper->via_workflow(
    tester => $test,
    hostname => "acme-$uuid.local",
    requestor_gname => 'Till',
    requestor_name => $uuid,
    requestor_email => 'tilltom@morning',
);

$test->runcmd_ok('search_cert', {
    CSR_SERIAL => $cert_info->{req_key},
    PKI_REALM => "_ANY"
}, "Search cert by CSR serial");

cmp_bag $test->get_msg->{PARAMS}, [
    superhashof({ IDENTIFIER => $cert_info->{identifier} })
], "Correct result";


# By PROFILE
$test->runcmd_ok('search_cert', {
    IDENTIFIER => $cert_info->{identifier},
    PROFILE => $cert_info->{profile},
}, "Search cert by profile");

cmp_bag $test->get_msg->{PARAMS}, [
    superhashof({ IDENTIFIER => $cert_info->{identifier} })
], "Correct result";

# By NOTBEFORE/NOTAFTER (Int: searches "other side" of validity)
search_cert_ok "that is/was valid before given date", {
    NOTBEFORE => $dbdata->cert("expired_root")->db->{notafter} + 100,
    PKI_REALM => "_ANY"
}, qw( expired_root expired_signer expired_client );

search_cert_ok "that is will be valid after given date", {
    NOTAFTER => $dbdata->cert("acme_root")->db->{notbefore} + 100,
    PKI_REALM => $dbdata->cert("acme_root")->db->{pki_realm}
}, qw( acme_root acme_signer acme_client );

# By CERT_ATTRIBUTES list of conditions to search in attributes (KEY, VALUE, OPERATOR)
# OPERATOR = [ EQUAL | LIKE | BETWEEN ]
# Note that the $uuid is used both in requestor name and hostname (subject)
$test->runcmd_ok('search_cert', {
    CERT_ATTRIBUTES => [
        { KEY => 'meta_requestor', VALUE => "*$uuid*" }, # default operator is LIKE
        { KEY => 'meta_email', VALUE => 'tilltom@morning', OPERATOR => 'EQUAL' },
    ],
    PKI_REALM => "_ANY"
}, "Search cert by attributes");

cmp_deeply $test->get_msg->{PARAMS}, [
    superhashof({ SUBJECT => re(qr/$uuid/i) })
], "Correct result";

$dbdata->delete_all;

$test->disconnect;
