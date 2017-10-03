#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename qw( dirname );
use FindBin qw( $Bin );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;
use Math::BigInt;
use Data::UUID;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use TestCfg;
use OpenXPKI::Test::More;
use OpenXPKI::Test::CertHelper;
use OpenXPKI::Test;

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
$test->plan( tests => 58 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#

# Import test certificates
my $oxitest = OpenXPKI::Test->new;
my $dbdata = $oxitest->certhelper_database;
$oxitest->insert_testcerts;


=pod

CERT_SERIAL                 Int|Str: decimal serial or hex (starting with "0x")
PKI_REALM                   Str: default is the sessions realm, _any for global search
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

ORDER           Str: column to order by (default: cert_key) --> remove "CERTIFICATE."
LIMIT           Int: limit results
START           Int: offset for results
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
# If the last parameter is "ORDERED" then the order of the results will be
# considered, otherwise not.
sub search_cert_ok {
    my ($message, $conditions, @expected_names) = @_;

    my $val;
    # Only extract last element if it equals "ORDERED" (otherwise put it back and make term return 0)
    my $respect_order = (($val = pop @expected_names) eq "ORDERED") ? 1 : push(@expected_names, $val) && 0;
    my @hashes = map { superhashof({ SUBJECT_KEY_IDENTIFIER => $dbdata->cert($_)->id }) } @expected_names;

    $test->runcmd_ok('search_cert', $conditions, "Search cert $message")
        or die Dumper($test->get_msg);
    cmp_deeply $test->get_msg->{PARAMS}, ($respect_order ? \@hashes : bag(@hashes)), "Correct result";
}

$test->runcmd_ok('search_cert', {
    CERT_SERIAL => $dbdata->cert("alpha_root_2")->db->{cert_key}
}, "Search cert without giving PKI realm");
is scalar(@{ $test->get_msg->{PARAMS} }), 0, "Should not return any results";

search_cert_ok "by serial (decimal) and PKI realm _ANY", {
    CERT_SERIAL => $dbdata->cert("alpha_root_2")->db->{cert_key},
    PKI_REALM => $dbdata->cert("alpha_root_2")->db->{pki_realm}
}, qw( alpha_root_2 );

search_cert_ok "by serial (decimal) and PKI realm", {
    CERT_SERIAL => $dbdata->cert("alpha_root_2")->db->{cert_key},
    PKI_REALM => "_ANY"
}, qw( alpha_root_2 );

search_cert_ok "by serial (hex) and specific PKI realm", {
    CERT_SERIAL => Math::BigInt->new($dbdata->cert("alpha_root_2")->db->{cert_key})->as_hex,
    PKI_REALM => $dbdata->cert("alpha_root_2")->db->{pki_realm}
}, qw( alpha_root_2 );

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
    PKI_REALM => $dbdata->cert("alpha_root_1")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 1);

search_cert_ok "by identifier", {
    IDENTIFIER => $dbdata->cert("beta_alice_1")->db->{identifier},
    PKI_REALM => "_ANY"
}, qw( beta_alice_1 );

my $test_identifier = $dbdata->cert("alpha_root_2")->db->{identifier};
search_cert_ok "by issuer", {
    ISSUER_IDENTIFIER => $test_identifier,
    PKI_REALM => "_ANY"
}, $dbdata->cert_names_where(issuer_identifier => $test_identifier);

search_cert_ok "by subject key id", {
    SUBJECT_KEY_IDENTIFIER => $dbdata->cert("alpha_root_2")->db->{subject_key_identifier},
    PKI_REALM => "_ANY"
}, qw( alpha_root_2 );

my $test_authority_key_identifier = $dbdata->cert("beta_root_1")->db->{authority_key_identifier};
search_cert_ok "by authority key id", {
    AUTHORITY_KEY_IDENTIFIER => $test_authority_key_identifier,
    PKI_REALM => "_ANY"
}, $dbdata->cert_names_where(authority_key_identifier => $test_authority_key_identifier);

search_cert_ok "by subject (exact match)", {
    SUBJECT => $dbdata->cert("beta_alice_1")->db->{subject},
    PKI_REALM => "_ANY"
}, qw( beta_alice_1 );

my $subject_part = join(",", (split(",", $dbdata->cert("beta_root_1")->db->{subject}))[1,2]);
search_cert_ok "by subject (with wildcards)", {
    SUBJECT => "*$subject_part*", # will be similar to *OU=ACME,DC=OpenXPKI*
    PKI_REALM => $dbdata->cert("beta_root_1")->db->{pki_realm},
}, $dbdata->cert_names_by_realm_gen(beta => 1);

search_cert_ok "by issuer DN (exact match)", {
    ISSUER_DN => $dbdata->cert("gamma_bob_1")->db->{issuer_dn},
    PKI_REALM => "_ANY"
}, qw( gamma_bob_1 );

my $issuer_dn_part = (split("=", (split(",", $dbdata->cert("gamma_bob_1")->db->{issuer_dn}))[0]))[1];
search_cert_ok "by issuer DN (with wildcards)", {
    ISSUER_DN => "*$issuer_dn_part*", # will be similar to *GAMMA Signing CA*
    PKI_REALM => "_ANY"
}, qw( gamma_bob_1 );

search_cert_ok "by validity date", {
    VALID_AT => $dbdata->cert("alpha_root_1")->db->{notbefore} + 100,
    PKI_REALM => "_ANY"
}, $dbdata->cert_names_by_realm_gen(alpha => 1);

search_cert_ok "and limit results", {
    ORDER => "CERTIFICATE.SUBJECT",
    REVERSE => 0,
    LIMIT => 1,
    PKI_REALM => $dbdata->cert("beta_root_1")->db->{pki_realm},
}, qw( beta_alice_1 );

# LIMIT and START
search_cert_ok "limit results and use offset", {
    ORDER => "CERTIFICATE.SUBJECT",
    REVERSE => 0,
    LIMIT => 2,
    START => 1,
    PKI_REALM => $dbdata->cert("beta_root_1")->db->{pki_realm},
}, qw( beta_bob_1 beta_datavault_1 ), "ORDERED";

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
}, "Search cert by profile") or diag Dumper($test->get_msg);

cmp_bag $test->get_msg->{PARAMS}, [
    superhashof({ IDENTIFIER => $cert_info->{identifier} })
], "Correct result";

# By NOTBEFORE/NOTAFTER (Int: searches "other side" of validity)
search_cert_ok "whose validity period started before given date (NOTBEFORE < x)", {
    NOTBEFORE => $dbdata->cert("alpha_root_1")->db->{notbefore} + 100,
    PKI_REALM => "_ANY"
}, $dbdata->cert_names_by_realm_gen(alpha => 1); # chain #1 are expired certificates

search_cert_ok "that was not yet valid at given date (NOTBEFORE > x)", {
    # TODO #legacydb Using old DB layer syntax in "search_cert"
    NOTBEFORE => { OPERATOR => "GREATER_THAN", VALUE => $dbdata->cert("alpha_root_3")->db->{notbefore} - 100 },
    PKI_REALM => $dbdata->cert("alpha_root_3")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 3); # chain #3 are future certificates

search_cert_ok "whose validity period ends after given date (NOTAFTER > x)", {
    NOTAFTER => $dbdata->cert("alpha_root_2")->db->{notafter} - 100,
    PKI_REALM => $dbdata->cert("alpha_root_2")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 2), $dbdata->cert_names_by_realm_gen(alpha => 3);

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

# Test NOT_EQUAL operator
$test->runcmd_ok('search_cert', {
    CERT_ATTRIBUTES => [
        { KEY => 'meta_requestor', VALUE => "Till $uuid", OPERATOR => 'NOT_EQUAL' },
    ],
    PKI_REALM => "_ANY"
}, "Search cert by attributes");

cmp_deeply $test->get_msg->{PARAMS}, array_each(
    # Make sure the UUID does NOT match
    superhashof({ SUBJECT => code(sub { (shift !~ /$uuid/i) or (0, "UUID matched") } ) })
), "Correct result";


# ENTITY_ONLY     Bool: show only certificates issued by this ca (where CSR_SERIAL is set)
$test->runcmd_ok('search_cert', {
    ENTITY_ONLY => 1,
    PKI_REALM => "_ANY",
}, "Search cert only from this CA entity");

cmp_deeply $test->get_msg->{PARAMS}, array_each(
    superhashof({ CSR_SERIAL => re(qr/^\d+$/) })
), "Correct result";

# Github issue #501 - SQL JOIN statement breaks when searching for attributes AND profile
$test->runcmd_ok('search_cert', {
    CERT_ATTRIBUTES => [
        { KEY => 'meta_requestor', VALUE => "*$uuid*" }, # default operator is LIKE
        { KEY => 'meta_email', VALUE => 'tilltom@morning', OPERATOR => 'EQUAL' },
    ],
    PROFILE => $cert_info->{profile},
    PKI_REALM => "_ANY"
}, "Search cert by attributes and profile (issue #501)") or diag ref($test->error);

cmp_deeply $test->get_msg->{PARAMS}, [
    superhashof({ SUBJECT => re(qr/$uuid/i) })
], "Correct result";

# Github issue #575 - search_cert fails on Oracle when order = identifier
$test->runcmd_ok('search_cert', {
    CERT_ATTRIBUTES => [
        { KEY => 'meta_requestor', VALUE => "*$uuid*" }, # default operator is LIKE
        { KEY => 'meta_email', VALUE => 'tilltom@morning', OPERATOR => 'EQUAL' },
    ],
    ORDER => "IDENTIFIER",
    PKI_REALM => "_ANY"
}, "Search cert by attributes and with ORDER = 'identifier' (issue #575)") or diag ref($test->error);

cmp_deeply $test->get_msg->{PARAMS}, [
    superhashof({ SUBJECT => re(qr/$uuid/i) })
], "Correct result";

$oxitest->delete_testcerts; # only deletes those from OpenXPKI::Test::CertHelper::Database
$test->disconnect;
