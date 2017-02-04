#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;

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
$test->plan( tests => 11 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#
my $db_helper = DbHelper->new;
my $test_certs = OpenXPKI::Test::CertHelper->new(tester => $test);

# Import test certificates
$db_helper->delete_cert_by_id($test_certs->all_cert_ids); # just in case a previous test left some
$db_helper->insert_test_cert($test_certs->certs->{$_}->database) for @{ $test_certs->all_cert_names };

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
VALID_AT                    Int|Datetime|ArrayRef: epoch or list of epochs

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

# By CERT_SERIAL and PKI_REALM
$test->runcmd_ok('search_cert', { CERT_SERIAL => "13135268448054154766", PKI_REALM => "acme" }, "Search cert by serial (decimal) and PK realm");
$test->is($test->get_msg->{PARAMS}->[0]->{SUBJECT_KEY_IDENTIFIER}, $test_certs->certs->{acme_root}->id, "Return correct certificate");

$test->runcmd_ok('search_cert', { CERT_SERIAL => "0xb649d90f53aa160e", PKI_REALM => "acme" }, "Search cert by serial (hex) and PK realm");
$test->is($test->get_msg->{PARAMS}->[0]->{SUBJECT_KEY_IDENTIFIER}, $test_certs->certs->{acme_root}->id, "Return correct certificate");

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

$test->runcmd_ok('search_cert', { STATUS => "EXPIRED", PKI_REALM => "_ANY" }, "Search expired certificates");
cmp_bag $test->get_msg->{PARAMS}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $test_certs->certs->{$_}->id }) } qw(expired_root expired_signer)
], "Correct result";

#use Data::Dumper;
#diag Dumper($test->get_msg);
#cmp_bag $test->get_msg->{PARAMS}->{imported}, [
#    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$all_ids
#], "Correctly list imported certs";


$db_helper->delete_cert_by_id($test_certs->all_cert_ids);

$test->disconnect;
