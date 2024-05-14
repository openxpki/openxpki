#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

#
# Init helpers
#

# Import test certificates
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Workflows WorkflowCreateCert ) ],
);
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
            VALUE =>  $self->session_param('user')->{name},
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

    # MODE 1: Do not check but return query results

    if (scalar(@expected_names) and $expected_names[0] eq "NO_CHECK") {
        my $result = [];
        lives_ok {
            $result = $oxitest->api2_command(search_cert => $conditions);
        } "Search cert $message";
        return $result;
    }

    # MODE 2: Check query results

    # Only extract last element if it equals "ORDERED" (otherwise put it back and make term return 0)
    my $val;
    my $respect_order = scalar(@expected_names)
        ? (($val = pop @expected_names) eq "ORDERED") ? 1 : push(@expected_names, $val) && 0
        : 0;
    my @hashes = map { +{ subject_key_identifier => $dbdata->cert($_)->subject_key_id } } @expected_names;

    my $result;
    lives_and {
        $result = $oxitest->api2_command(search_cert => { %$conditions, return_columns => "subject_key_identifier" } );
        cmp_deeply $result, ($respect_order ? \@hashes : bag(@hashes)) or diag explain $result;
    } "Search cert $message";
}



search_cert_ok "by serial (decimal) and PKI realm _ANY", {
    cert_serial => $dbdata->cert("alpha-root-2")->db->{cert_key},
    pki_realm => $dbdata->cert("alpha-root-2")->db->{pki_realm}
}, qw( alpha-root-2 );

search_cert_ok "by serial (decimal) and PKI realm", {
    cert_serial => $dbdata->cert("alpha-root-2")->db->{cert_key},
    pki_realm => "_ANY"
}, qw( alpha-root-2 );

search_cert_ok "by serial (hex) and specific PKI realm", {
    cert_serial => Math::BigInt->new($dbdata->cert("alpha-root-2")->db->{cert_key})->as_hex,
    pki_realm => $dbdata->cert("alpha-root-2")->db->{pki_realm}
}, qw( alpha-root-2 );

my $result;

# Custom ORDER
$result = search_cert_ok "and order by NOTBEFORE descending (default)", { order => "notbefore" }, "NO_CHECK";
my $last_value;
my $sort_ok = scalar(@{ $result }) > 0; # make sure certificates are returned
while (my $cert = shift @{ $result } and $sort_ok) {
    $sort_ok = 0 if ($last_value and $last_value < $cert->{notbefore});
    $last_value = $cert->{notbefore};
}
ok($sort_ok, "Certificates are sorted correctly");

# Custom ORDER not reversed
$result = search_cert_ok "and order by NOTBEFORE ascending", { order => "notbefore", reverse => 0 }, "NO_CHECK";
$sort_ok = scalar(@{ $result }) > 0; # make sure certificates are returned
while (my $cert = shift @{ $result } and $sort_ok) {
    $sort_ok = 0 if ($last_value and $last_value > $cert->{notbefore});
    $last_value = $cert->{notbefore};
}
ok($sort_ok, "Certificates are sorted correctly");

# Various attributes
search_cert_ok "by status VALID", {
    status => "VALID",
    pki_realm => $dbdata->cert("alpha-root-2")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 2);

search_cert_ok "by status EXPIRED", {
    status => "EXPIRED",
    pki_realm => $dbdata->cert("alpha-root-1")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 1);

search_cert_ok "by identifier", {
    identifier => $dbdata->cert("beta-alice-1")->db->{identifier},
    pki_realm => "_ANY"
}, qw( beta-alice-1 );

my $test_identifier = $dbdata->cert("alpha-root-2")->db->{identifier};
search_cert_ok "by issuer", {
    issuer_identifier => $test_identifier,
    pki_realm => "_ANY"
}, $dbdata->cert_names_where(issuer_identifier => $test_identifier);

search_cert_ok "by subject key id", {
    subject_key_identifier => $dbdata->cert("alpha-root-2")->db->{subject_key_identifier},
    pki_realm => "_ANY"
}, qw( alpha-root-2 );

my $test_authority_key_identifier = $dbdata->cert("beta-root-1")->db->{authority_key_identifier};
search_cert_ok "by authority key id", {
    authority_key_identifier => $test_authority_key_identifier,
    pki_realm => "_ANY"
}, $dbdata->cert_names_where(authority_key_identifier => $test_authority_key_identifier);

search_cert_ok "by subject (exact match)", {
    subject => $dbdata->cert("beta-alice-1")->db->{subject},
    pki_realm => "_ANY"
}, qw( beta-alice-1 );

my $subject_part = join(",", (split(",", $dbdata->cert("beta-root-1")->db->{subject}))[1,2]);
search_cert_ok "by subject (with wildcards)", {
    subject => "*$subject_part*", # will be similar to *OU=ACME,DC=OpenXPKI*
    pki_realm => $dbdata->cert("beta-root-1")->db->{pki_realm},
}, $dbdata->cert_names_by_realm_gen(beta => 1);

search_cert_ok "by issuer DN (exact match)", {
    issuer_dn => $dbdata->cert("gamma-bob-1")->db->{issuer_dn},
    pki_realm => "_ANY"
}, qw( gamma-bob-1 );

my $issuer_dn_part = (split("=", (split(",", $dbdata->cert("gamma-bob-1")->db->{issuer_dn}))[0]))[1];
search_cert_ok "by issuer DN (with wildcards)", {
    issuer_dn => "*$issuer_dn_part*", # will be similar to *GAMMA Signing CA*
    pki_realm => "_ANY"
}, qw( gamma-bob-1 );

search_cert_ok "by validity date", {
    valid_before  => $dbdata->cert("alpha-root-1")->db->{notbefore} + 100,
    expires_after => $dbdata->cert("alpha-root-1")->db->{notbefore} + 100,
    pki_realm => "_ANY"
}, $dbdata->cert_names_by_realm_gen(alpha => 1);

search_cert_ok "and limit results", {
    order => "subject",
    reverse => 0,
    limit => 1,
    pki_realm => $dbdata->cert("beta-root-1")->db->{pki_realm},
}, qw( beta-alice-1 );

# LIMIT and START
search_cert_ok "limit results and use offset", {
    order => "subject",
    reverse => 0,
    limit => 2,
    start => 1,
    pki_realm => $dbdata->cert("beta-root-1")->db->{pki_realm},
}, qw( beta-bob-1 beta-datavault-1 ), "ORDERED";


# By CSR serial
my $uuid = Data::UUID->new->create_str;
my $cert_info = $oxitest->create_cert(
    hostname => "acme-$uuid.local",
    requestor_realname => "Till $uuid",
    requestor_email => 'tilltom@morning',
);


$result = search_cert_ok "by CSR serial", {
    csr_serial => $cert_info->{req_key},
    pki_realm => "_ANY"
}, "NO_CHECK";

cmp_bag $result, [
    superhashof({ identifier => $cert_info->{identifier} })
], "Correct result";


# By PROFILE
$result = search_cert_ok "by profile", {
    identifier => $cert_info->{identifier},
    profile => $cert_info->{profile},
}, "NO_CHECK";

cmp_bag $result, [
    superhashof({ identifier => $cert_info->{identifier} })
], "Correct result";

# By validity date
search_cert_ok "whose validity period started before given date (valid_before)", {
    valid_before => $dbdata->cert("alpha-root-1")->db->{notbefore} + 100,
    pki_realm => "_ANY"
}, $dbdata->cert_names_by_realm_gen(alpha => 1); # chain #1 are expired certificates

my $ar3nb = $dbdata->cert("alpha-root-3")->db->{notbefore};

search_cert_ok "that was not yet valid at given date (valid_after)", {
    valid_after => $ar3nb - 100,
    pki_realm => $dbdata->cert("alpha-root-3")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 3); # chain #3 are future certificates

search_cert_ok "whose validity starts between two given dates", {
    valid_after => $ar3nb - 100,
    valid_before => $ar3nb + 100,
    pki_realm => $dbdata->cert("alpha-root-3")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 3); # chain #3 are future certificates

my $ar2na = $dbdata->cert("alpha-root-2")->db->{notafter};

search_cert_ok "whose validity period ends after given date (expires_after)", {
    expires_after => $ar2na - 100,
    pki_realm => $dbdata->cert("alpha-root-2")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 2), $dbdata->cert_names_by_realm_gen(alpha => 3);

search_cert_ok "whose validity period ends betweem two given dates", {
    expires_after => $ar2na - 100,
    expires_before => $ar2na + 100,
    pki_realm => $dbdata->cert("alpha-root-2")->db->{pki_realm}
}, $dbdata->cert_names_by_realm_gen(alpha => 2);

# Test that status 'VALID' and valid_before (both lead to setting notbefore) lead to
# setting notbefore to the stricter (i.e. lower) value. This should result in
# 0 certificates as alpha-root-3 is valid in the future.
$result = search_cert_ok "that is VALID now and valid before somewhen in the future", {
    status => 'VALID',              # sets notbefore < now
    valid_before => $ar3nb + 100,   # sets notbefore < $ar3nb + 100
    valid_after => $ar3nb - 100,    # only used to filter out certs from other generations
    pki_realm => $dbdata->cert("alpha-root-3")->db->{pki_realm}
}, ();

# By CERT_ATTRIBUTES list of conditions to search in attributes (KEY, VALUE, OPERATOR)
# OPERATOR = [ EQUAL | LIKE | BETWEEN ]
# Note that the $uuid is used both in requestor name and hostname (subject)
$result = search_cert_ok "by attributes (operators LIKE and EQUAL)" => {
    cert_attributes => {
        meta_requestor => { -like => "%$uuid%" },
        meta_email => 'tilltom@morning',
    },
    pki_realm => "_ANY"
}, "NO_CHECK";

cmp_deeply $result, [
    superhashof({ subject => re(qr/$uuid/i) })
], "Correct result";

# Test NOT_EQUAL operator
$result = search_cert_ok "by attributes (operator NOT_EQUAL)" => {
    cert_attributes => {
        meta_requestor => { '!=' => "Till $uuid" },
    },
    pki_realm => "_ANY"
}, "NO_CHECK";

cmp_deeply $result, array_each(
    # Make sure the UUID does NOT match
    superhashof({ subject => code(sub { (shift !~ /$uuid/i) or (0, "UUID matched") } ) })
), "Correct result";

# ENTITY_ONLY     Bool: show only certificates issued by this ca (where CSR_SERIAL is set)
$result = search_cert_ok "only from this CA entity" => {
    entity_only => 1,
    pki_realm => "_ANY",
    return_columns => "req_key",
}, "NO_CHECK";

cmp_deeply $result, array_each(
    { req_key => re(qr/^\d+$/) }
), "Correct result";

# Github issue #501 - SQL JOIN statement breaks when searching for attributes AND profile
$result = search_cert_ok "by attributes and profile (issue #501)" => {
    cert_attributes => {
        meta_requestor => { -like => "%$uuid%" },
        meta_email => 'tilltom@morning',
    },
    profile => $cert_info->{profile},
    pki_realm => "_ANY"
}, "NO_CHECK";

cmp_deeply $result, [
    superhashof({ subject => re(qr/$uuid/i) })
], "Correct result";

# Github issue #575 - search_cert fails on Oracle when ORDER = 'identifier'
$result = search_cert_ok "by attributes and with ORDER = 'identifier' (issue #575)" => {
    cert_attributes => {
        meta_requestor => { -like => "%$uuid%" },
        meta_email => 'tilltom@morning',
    },
    order => "identifier",
    pki_realm => "_ANY"
}, "NO_CHECK";

cmp_deeply $result, [
    superhashof({ subject => re(qr/$uuid/i) })
], "Correct result";

$oxitest->delete_testcerts; # only deletes those from OpenXPKI::Test::CertHelper::Database

done_testing;
