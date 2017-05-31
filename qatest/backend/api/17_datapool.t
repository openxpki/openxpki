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
use Data::UUID;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use TestCfg;
use OpenXPKI::Test::More;
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
$test->plan( tests => 37 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";



my $namespace = sprintf "test-%s", Data::UUID->new->create_str;

sub set_entry_ok {
    my ($params, $message) = @_;
    $test->runcmd_ok('set_data_pool_entry', { NAMESPACE => $namespace, %$params }, $message)
        or diag Dumper($test->get_msg);
}

sub set_entry_fails {
    my ($params, $error, $message) = @_;
    my $ok = $test->runcmd('set_data_pool_entry', { NAMESPACE => $namespace, %$params });
    if ($ok) {
        fail $message;
        return;
    }
    like $test->error || '', ref $error eq 'Regexp' ? $error : qr(\Q$error\E), $message;
}

sub entry_is {
    my ($key, @expected_entries, $message) = @_;
    $test->runcmd('get_data_pool_entry', { NAMESPACE => $namespace, KEY => $key }) or die Dumper($test->get_msg);
    cmp_deeply $test->get_msg->{PARAMS}, @expected_entries, $message;
}

#
# Check parameter validation
#
$test->runcmd('set_data_pool_entry', { KEY => "pill", VALUE => "red" });
$test->error_is(
    "I18N_OPENXPKI_SERVER_API_INVALID_PARAMETER",
    "Complain when trying to store entry without NAMESPACE"
);

set_entry_fails { VALUE => "red" },
    "I18N_OPENXPKI_SERVER_API_INVALID_PARAMETER",
    "Complain when trying to store entry without KEY";

set_entry_fails { KEY => "pill" },
    "I18N_OPENXPKI_SERVER_API_INVALID_PARAMETER",
    "Complain when trying to store entry without VALUE";

set_entry_fails { KEY => "pill", VALUE => "red", EXPIRATION_DATE => -1000 },
    "I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE",
    "Complain when trying to store datapool entry with invalid expiration";

#
# Insert and read data (plain text)
#
entry_is "drug", undef,
    "Query non-existing entry";

# Store entry
set_entry_ok { KEY => "pill-01", VALUE => "red" },
    "Plaintext: store datapool entry";

# Try inserting a second time
set_entry_fails { KEY => "pill-01", VALUE => "red" },
    qr/.+/,
    "Plaintext: complain when trying to store same entry again";

# Forced overwrite
set_entry_ok { KEY => "pill-01", VALUE => "blue", FORCE => 1 },
    "Plaintext: store entry again while FORCE is with us";

entry_is "pill-01", superhashof({ VALUE => "blue" }),
    "Plaintext: load datapool entry";

# With expiration date
set_entry_ok { KEY => "pill-33", VALUE => "blue", EXPIRATION_DATE => time+1 },
    "Expiration: store entry with expiration date (now + 2 seconds)";

entry_is "pill-33", superhashof({ VALUE => "blue" }),
    "Expiration: load entry";

note "Wait for 2 seconds";
sleep 2;

set_entry_ok { KEY => "pill-dummy", VALUE => "dummy" },
    "Expiration: trigger datapool cleanup by creating another entry";


entry_is "pill-33", undef,
    "Expiration: entry should be gone";

#
# List entries
#
my $namespace2 = sprintf "test-%s", Data::UUID->new->create_str;

# Store some entries
my @some_uuids = map { Data::UUID->new->create_str } (1..10);
my $entry_no = 0;
for (@some_uuids) {
    $test->runcmd('set_data_pool_entry', {
        NAMESPACE => $namespace2,
        KEY => sprintf("pill-%02d", $entry_no, $_),
        VALUE => $_,
    }) and $entry_no++;
}
is $entry_no, scalar(@some_uuids), "Listing: store some entries";

# List entries
$test->runcmd_ok('list_data_pool_entries', {
    NAMESPACE => $namespace2,
}, "Listing: query all entries") or diag Dumper($test->get_msg);

$entry_no = 0;
cmp_deeply $test->get_msg->{PARAMS}, bag(
    map { { NAMESPACE => $namespace2, KEY => sprintf("pill-%02d", $entry_no++, $_) } } @some_uuids,
), "Listing: all stored entries are returned";

# List limited amount of entries
$test->runcmd_ok('list_data_pool_entries', { NAMESPACE => $namespace2, LIMIT => 1 },
    "Listing: query only first entry"
) or diag Dumper($test->get_msg);

cmp_deeply $test->get_msg->{PARAMS}, [ { NAMESPACE => $namespace2, KEY => "pill-00" } ],
    "Listing: correct entry is returned";

#
# Modify entry
#

# Modify key name
set_entry_ok { KEY => "renameme", VALUE => "secret" },
    "Create dummy entry to be renamed";

$test->runcmd_ok('modify_data_pool_entry', {
    NAMESPACE => $namespace,
    KEY => "renameme",
    NEWKEY => "shinynewname",
}, "Modify entry to set new key name") or diag Dumper($test->get_msg);

entry_is "renameme", undef,
    "Entry with old key is overwritten";

entry_is "shinynewname", superhashof({ VALUE => "secret" }),
    "Entry with new key is available";

# Delete entry by setting expiration date
set_entry_ok { KEY => "deleteme", VALUE => "dummy" },
    "Create dummy entry to be deleted";

entry_is "deleteme", superhashof({ VALUE => "dummy" }),
    "Dummy entry exists";

$test->runcmd_ok('modify_data_pool_entry', {
    NAMESPACE => $namespace,
    KEY => "deleteme",
    NEWKEY => "deleteme",
    EXPIRATION_DATE => 0,
}, "Delete entry via 'modify_data_pool_entry' with EXPIRATION_DATE => 0") or diag Dumper($test->get_msg);

set_entry_ok { KEY => "dummy", VALUE => "dummy" },
    "Trigger datapool cleanup by creating another entry";

entry_is "deleteme", undef,
    "Dummy entry was successfully deleted";

#
# Insert and read data (encrypted)
#
set_entry_ok { KEY => "pill-99", VALUE => "green", ENCRYPT => 1 },
    "Encrypted: store entry";

# Clear secrets cache
my $oxitest = OpenXPKI::Test->new;
my $dbi = $oxitest->dbi;
# helper init already empties table "secret", but we want to play safe
$dbi->start_txn;
$dbi->delete(from => 'secret', all => 1);
$dbi->commit;

# Check secrets cache
my $secrets = $dbi->select(from => 'secret', columns => [ '*' ])->fetchall_arrayref({});
is scalar(@$secrets), 0,
    "Secrets cache is empty after we cleared it";

# Read test data (encrypted)
entry_is "pill-99", superhashof({ VALUE => "green" }),
    "Encrypted: entry matches the one we stored";

# Check secrets cache
$secrets = $dbi->select(from => 'secret', columns => [ '*' ])->fetchall_arrayref({});
is scalar(@$secrets), 1,
    "Secrets cache contains one entry for data pool symmetric key";

# Read test data (encrypted) using cached key
entry_is "pill-99", superhashof({ VALUE => "green" }),
    "Encrypted: entry matches again the one we stored";

#
# Access to other PKI realm should be forbidden in subclasses of OpenXPKI::Server::Workflow
#
package OpenXPKI::Server::Workflow::Test::DataPool;

use Test::Exception;
use OpenXPKI::Test; # to import CTX into this package

$oxitest->setup_env->init_server('crypto_layer');

# Try accessing another PKI realm from within OpenXPKI::Server::Workflow namespace
throws_ok {
    CTX('api')->set_data_pool_entry(
        { NAMESPACE => $namespace, PKI_REALM => "dummy", KEY => "pill-78", VALUE => "red" },
    )
}
    qr/pki realm/i,
    "Complain about access to other PKI realm from within OpenXPKI::Server::Workflow (set_data_pool_entry)";

throws_ok {
    CTX('api')->get_data_pool_entry(
        { NAMESPACE => $namespace, PKI_REALM => "dummy", KEY => "pill-78" },
    )
}
    qr/pki realm/i,
    "Complain about access to other PKI realm from within OpenXPKI::Server::Workflow (get_data_pool_entry)";

throws_ok {
    CTX('api')->list_data_pool_entries(
        { NAMESPACE => $namespace, PKI_REALM => "dummy" },
    )
}
    qr/pki realm/i,
    "Complain about access to other PKI realm from within OpenXPKI::Server::Workflow (list_data_pool_entries)";

# Try accessing "sys." namespace from within OpenXPKI::Server::Workflow namespace
throws_ok {
    CTX('api')->set_data_pool_entry(
        { NAMESPACE => "sys.test", KEY => "pill-79", VALUE => "red" },
    )
}
    qr/namespace/i,
    "Complain about access to system namespace from within OpenXPKI::Server::Workflow";
