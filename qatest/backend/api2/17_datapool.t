#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use Data::UUID;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 34;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( TestRealms CryptoLayer )],
);
$oxitest->insert_testcerts; # needed for encryption tests that eventually access alias "alpha-datavault"


my $namespace = sprintf "test-%s", Data::UUID->new->create_str;

sub set_entry_ok {
    my ($params, $message) = @_;
    lives_and {
        ok $oxitest->api2_command('set_data_pool_entry' => { namespace => $namespace, %$params });
    } $message;
}

sub set_entry_fails {
    my ($params, $error, $message) = @_;
    throws_ok {
        $oxitest->api2_command('set_data_pool_entry' => { namespace => $namespace, %$params });
    } (ref $error eq 'Regexp' ? $error : qr(\Q$error\E)), $message;
}

sub entry_is {
    my ($key, @expected_entries, $message) = @_;
    lives_and {
        my $result = $oxitest->api2_command('get_data_pool_entry' => { namespace => $namespace, key => $key });
        cmp_deeply $result, @expected_entries;
    } $message;
}

#
# Check parameter validation
#
set_entry_fails { key => "pill", value => "red", expiration_date => -1000 },
    "I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE",
    "Complain when trying to store datapool entry with invalid expiration";

#
# Insert and read data (plain text)
#
entry_is "drug", undef,
    "Query non-existing entry";

# Store entry
set_entry_ok { key => "pill-01", value => "red" },
    "Plaintext: store datapool entry";

# Try inserting a second time
set_entry_fails { key => "pill-01", value => "red" },
    qr/.+/,
    "Plaintext: complain when trying to store same entry again";

# Forced overwrite
set_entry_ok { key => "pill-01", value => "blue", force => 1 },
    "Plaintext: store entry again while FORCE is with us";

entry_is "pill-01", superhashof({ value => "blue" }),
    "Plaintext: load datapool entry";

# With expiration date
set_entry_ok { key => "pill-33", value => "blue", expiration_date => time+1 },
    "Expiration: store entry with expiration date (now + 2 seconds)";

entry_is "pill-33", superhashof({ value => "blue" }),
    "Expiration: load entry";

note "Wait for 2 seconds";
sleep 2;

set_entry_ok { key => "pill-dummy", value => "dummy" },
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
    $oxitest->api2_command('set_data_pool_entry' => {
        namespace => $namespace2,
        key => sprintf("pill-%02d", $entry_no, $_),
        value => $_,
    }) and $entry_no++;
}
is $entry_no, scalar(@some_uuids), "Listing: store some entries";

# List entries
lives_and {
    my $result = $oxitest->api2_command('list_data_pool_entries' => {
        namespace => $namespace2,
    });
    $entry_no = 0;
    cmp_deeply $result, bag(
        map { { namespace => $namespace2, key => sprintf("pill-%02d", $entry_no++, $_) } } @some_uuids,
    );
} "Listing: all stored entries";

# List limited amount of entries
lives_and {
    my $result = $oxitest->api2_command('list_data_pool_entries' => {
        namespace => $namespace2, limit => 1
    });
    cmp_deeply $result, [ { namespace => $namespace2, key => "pill-00" } ];
} "Listing: first entry";

#
# Modify entry
#

# Modify key name
set_entry_ok { key => "renameme", value => "secret" },
    "Create dummy entry to be renamed";

lives_ok {
    $oxitest->api2_command('modify_data_pool_entry' => {
        namespace => $namespace,
        key => "renameme",
        newkey => "shinynewname",
    });
} "Modify entry to set new key name";

entry_is "renameme", undef,
    "Entry with old key is overwritten";

entry_is "shinynewname", superhashof({ value => "secret" }),
    "Entry with new key is available";

# Delete entry by setting expiration date
set_entry_ok { key => "deleteme", value => "dummy" },
    "Create dummy entry to be deleted";

entry_is "deleteme", superhashof({ value => "dummy" }),
    "Dummy entry exists";

lives_ok {
    $oxitest->api2_command('modify_data_pool_entry' => {
        namespace => $namespace,
        key => "deleteme",
        newkey => "deleteme",
        expiration_date => 0,
    });
} "Delete entry via 'modify_data_pool_entry' by setting EXPIRATION_DATE to 0";

set_entry_ok { key => "dummy", value => "dummy" },
    "Trigger datapool cleanup by creating another entry";

entry_is "deleteme", undef,
    "Dummy entry was successfully deleted";

# Reset expiration date
my $expiry = time + 5;
set_entry_ok { key => "forever", value => "secret", expiration_date => $expiry },
    "Create dummy entry to be renamed";

entry_is "forever", superhashof({ expiration_date => $expiry }), "Expiration date was correctly set";

lives_and {
    $oxitest->api2_command('modify_data_pool_entry' => {
        namespace => $namespace,
        key => "forever",
        expiration_date => undef,
    });
    my $result = $oxitest->api2_command('get_data_pool_entry' => { namespace => $namespace, key => "forever" });
    ok not(defined $result->{expiration_date});

} "Modify entry via 'modify_data_pool_entry' to not expire";

#
# Insert and read data (encrypted)
#
set_entry_ok { key => "pill-99", value => "green", encrypt => 1 },
    "Encrypted: store entry";

# Clear secrets cache
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
entry_is "pill-99", superhashof({ value => "green" }),
    "Encrypted: entry matches the one we stored";

# Check secrets cache
$secrets = $dbi->select(from => 'secret', columns => [ '*' ])->fetchall_arrayref({});
is scalar(@$secrets), 1,
    "Secrets cache contains one entry for data pool symmetric key";

# Read test data (encrypted) using cached key
entry_is "pill-99", superhashof({ value => "green" }),
    "Encrypted: entry matches again the one we stored";

#
# Access to other PKI realm should be forbidden in subclasses of OpenXPKI::Server::Workflow
#
package OpenXPKI::Server::Workflow::Test::DataPool;

use Test::Exception;
use OpenXPKI::Test; # to import CTX into this package

# Try accessing another PKI realm from within OpenXPKI::Server::Workflow namespace
throws_ok {
    CTX('api2')->set_data_pool_entry(
        namespace => $namespace, pki_realm => "dummy", key => "pill-78", value => "red",
    )
}
    qr/pki realm/i,
    "Complain about access to other PKI realm from within OpenXPKI::Server::Workflow (set_data_pool_entry)";

throws_ok {
    CTX('api2')->get_data_pool_entry(
        namespace => $namespace, pki_realm => "dummy", key => "pill-78",
    )
}
    qr/pki realm/i,
    "Complain about access to other PKI realm from within OpenXPKI::Server::Workflow (get_data_pool_entry)";

throws_ok {
    CTX('api2')->list_data_pool_entries(
        namespace => $namespace, pki_realm => "dummy",
    )
}
    qr/pki realm/i,
    "Complain about access to other PKI realm from within OpenXPKI::Server::Workflow (list_data_pool_entries)";

# Try accessing "sys." namespace from within OpenXPKI::Server::Workflow namespace
throws_ok {
    CTX('api2')->set_data_pool_entry(
        namespace => "sys.test", key => "pill-79", value => "red",
    )
}
    qr/namespace/i,
    "Complain about access to system namespace from within OpenXPKI::Server::Workflow";

$oxitest->delete_testcerts;
