use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../..";

# Pre-load CGI::Session::Driver::openxpki from its non-standard path so that
# Module::Load inside Session.pm finds the package already registered.
BEGIN {
    require "$FindBin::Bin/../../CGI_Session_Driver/openxpki.pm"; ## no critic (Modules::RequireBarewordIncludes)
    $INC{"CGI/Session/Driver/openxpki.pm"} = "$FindBin::Bin/../../CGI_Session_Driver/openxpki.pm";
}

use Test::More;
use Test::Exception;
use Test::Deep ':v1';
use File::Temp qw(tempfile);
use Log::Log4perl qw(:easy);
use Digest::SHA qw( hmac_sha256_hex );

BEGIN {
    Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $TRACE : $OFF);
}

# Setup: SQLite database via DatabaseTest

require "$Bin/../31_database/DatabaseTest.pm"; ## no critic (Modules::RequireBarewordIncludes)

my (undef, $sqlite_db) = tempfile(UNLINK => 1);

# Switch SQLite to WAL mode
system(qq(sqlite3 $sqlite_db "PRAGMA journal_mode = WAL")) == 0
    or BAIL_OUT("Failed to set SQLite WAL mode (exit code: " . ($? >> 8) . ")");

my $db = DatabaseTest->new(
    test_only => ['SQLite'],
    sqlite_db => $sqlite_db,
    columns => [ # yes an ArrayRef to have a defined order!
        session_id => "varchar(255) NOT NULL PRIMARY KEY",
        data => "text",
        created => "integer NOT NULL",
        modified => "integer NOT NULL",
        ip_address => "varchar(45)",
    ],
);

my $dbi_params = $db->get_dbi_params('SQLite');

# Load Session class

use_ok 'OpenXPKI::Client::Service::WebUI::Session';

# create new session

$db->run("WebUI session", 3, sub {
    my $t = shift;

    my $sid;

    subtest 'Modify and flush to disk' => sub {
        my $session;
        lives_ok {
            $session = OpenXPKI::Client::Service::WebUI::Session->new(
                table_name => 'test',
                db_params => $dbi_params,
            );
        } 'Create new session';

        ok defined $session->id, 'Session has an ID';
        like $session->id, qr/^[a-f0-9]{32}$/, 'Session ID is 32-char hex (MD5)';

        # param()

        $session->param('foo', 'bar');
        is $session->param('foo'), 'bar', 'param() set and get';

        $session->param(key1 => 'val1', key2 => 'val2');
        is $session->param('key1'), 'val1', 'param() multi-set: key1';
        is $session->param('key2'), 'val2', 'param() multi-set: key2';

        $session->param('hash_val', { a => 1, b => 2 });
        is_deeply $session->param('hash_val'), { a => 1, b => 2 }, 'param() stores hashref';

        $session->param('array_val', [1, 2, 3]);
        is_deeply $session->param('array_val'), [1, 2, 3], 'param() stores arrayref';

        my @params = sort $session->param;
        cmp_bag \@params, [ qw( foo key1 key2 hash_val array_val ) ], 'param() with no args returns parameter names';

        # id()

        $sid = $session->id;
        ok defined $sid, 'id() returns a value';

        # expire()

        is $session->expire, undef, 'expire() returns undef before being set';
        $session->expire('1h');
        is $session->expire, 3600, 'expire("1h") sets to 3600 seconds';

        # Per-parameter expiration
        $session->expire('key1', 1);
        sleep 2;

        # flush()

        lives_ok { $session->flush } 'flush() succeeds';

        # Verify data is in the database
        my $ondisk = $t->get_data->[0];
        is $ondisk->[0], $session->id, "correct session ID in flushed data " . $session->id;

        done_testing 14;
    };

    # reload session from database
    subtest 'Restore' => sub {
        my $restored;
        lives_ok {
            $restored = OpenXPKI::Client::Service::WebUI::Session->new(
                table_name => 'test',
                db_params => $dbi_params,
                id => $sid,
            );
        } 'Restore session by ID';

        is $restored->id, $sid, 'Restored session has same ID';
        is $restored->param('foo'), 'bar', 'Restored session preserved param "foo"';
        is $restored->param('key1'), undef, 'Expired parameter is removed from restored session';
        is_deeply $restored->param('hash_val'), { a => 1, b => 2 }, 'Restored session preserved hashref param';
        is $restored->expire, 3600, 'Restored session preserved expiration';

        # clear() single parameter

        $restored->param('to_clear', 'temporary');
        is $restored->param('to_clear'), 'temporary', 'Set param for clear test';

        $restored->clear('to_clear');
        is $restored->param('to_clear'), undef, 'clear("to_clear") removes the parameter';

        # Other params unaffected
        is $restored->param('foo'), 'bar', 'clear() did not affect other params';

        # clear() all

        $restored->clear;
        my @remaining = $restored->param;
        is scalar(@remaining), 0, 'clear() with no args removes all public params';

        $restored->flush;

        done_testing 10;
    };

    # clone()
    subtest 'Clone' => sub {
        my $session;
        lives_ok {
            $session = OpenXPKI::Client::Service::WebUI::Session->new(
                table_name => 'test',
                db_params => $dbi_params,
            );
        } 'Create session';

        my $old_id = $session->id;

        $session->param('before_clone', 'yes');

        lives_ok { $session->flush } 'flush() succeeds';

        # Check old session data
        $t->dbi->commit; # underlying OpenXPKI::Database has AutoCommit = 0, so we trigger a fresh transaction = fresh read
        my $ids = [ map { $_->[0] } $t->get_data->@* ];
        cmp_deeply $ids, superbagof( $old_id ), 'Session is in database' or diag explain $ids;

        # Clone
        my $cloned;
        lives_ok {
            $cloned = $session->clone;
        } 'clone() succeeds';

        ok defined $cloned->id, 'Cloned session has an ID';
        isnt $cloned->id, $old_id, 'Cloned session has a different ID';

        # Check old session data
        $t->dbi->commit; # underlying OpenXPKI::Database has AutoCommit = 0, so we trigger a fresh transaction = fresh read
        $ids = [ map { $_->[0] } $t->get_data->@* ];
        cmp_deeply $ids, noneof( $old_id ), 'Old session is removed from database';

        # Cloned session is a fresh session (no inherited data)
        is $cloned->param('before_clone'), undef, 'Cloned session does not inherit old params';

        $cloned->param('after_clone', 'works');
        $cloned->flush;

        # Verify cloned session persists
        my $restore_clone = OpenXPKI::Client::Service::WebUI::Session->new(
            table_name => 'test',
            db_params => $dbi_params,
            id => $cloned->id,
        );
        is $restore_clone->param('after_clone'), 'works', 'Cloned session data persists after flush + reload';

        done_testing 9;
    };
});

# Encrypted sessions (encrypt_key)

$db->run("WebUI session (encrypted)", 3, sub {
    my $t = shift;

    my $encrypt_key = 'test-secret-key-for-aes-encrypt';

    my $sid;

    subtest 'Encrypted: create, store, verify DB contents' => sub {
        my $session;
        lives_ok {
            $session = OpenXPKI::Client::Service::WebUI::Session->new(
                table_name  => 'test',
                db_params   => $dbi_params,
                encrypt_key => $encrypt_key,
            );
        } 'Create encrypted session';

        $sid = $session->id;
        $session->param('secret', 'classified-data');
        $session->param('user', 'alice');

        lives_ok { $session->flush } 'flush() succeeds';

        # Inspect raw database contents
        $t->dbi->commit;
        my $rows = $t->get_data;
        is scalar @$rows, 1, 'One row in database';

        my ($stored_sid, $stored_data) = @{ $rows->[0] };

        # Session ID should be HMAC-hashed, not the raw MD5 ID
        isnt $stored_sid, $sid, 'Stored session ID differs from raw ID (HMAC-hashed)';
        is $stored_sid, hmac_sha256_hex($sid, $encrypt_key),
            'Stored ID is HMAC-SHA256 of raw ID';

        # Data should be encrypted (base64 encoded), not plaintext
        unlike $stored_data, qr/classified-data/,
            'Raw DB data does not contain plaintext param value';
        unlike $stored_data, qr/alice/,
            'Raw DB data does not contain plaintext param "user"';
        like $stored_data, qr{^[A-Za-z0-9+/=\s]+$},
            'Stored data looks like base64';

        done_testing 8;
    };

    subtest 'Encrypted: restore and decrypt session' => sub {
        my $restored;
        lives_ok {
            $restored = OpenXPKI::Client::Service::WebUI::Session->new(
                table_name  => 'test',
                db_params   => $dbi_params,
                encrypt_key => $encrypt_key,
                id          => $sid,
            );
        } 'Restore encrypted session by ID';

        is $restored->id, $sid, 'Restored session has same ID';
        is $restored->param('secret'), 'classified-data', 'Decrypted param "secret" matches';
        is $restored->param('user'), 'alice', 'Decrypted param "user" matches';

        done_testing 4;
    };

    subtest 'Wrong encrypt_key cannot restore session' => sub {
        my $session;
        lives_ok {
            $session = OpenXPKI::Client::Service::WebUI::Session->new(
                table_name  => 'test',
                db_params   => $dbi_params,
                encrypt_key => 'wrong-key-that-does-not-match',
                id          => $sid,
            );
        } 'Constructor succeeds with wrong key (no matching row)';

        # With wrong key, the HMAC-hashed session ID won't match any DB row,
        # so a new session is created with a fresh ID
        isnt $session->id, $sid, 'Wrong key yields a new session (different ID)';
        is $session->param('secret'), undef, 'No params in new session';

        done_testing 3;
    };
});

done_testing;
