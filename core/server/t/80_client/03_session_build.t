use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../..";

use File::Temp qw( tempdir );
use Test::More;
use Test::Exception;

require OpenXPKI::Client::Service::WebUI;
require OpenXPKI::Client::Service::WebUI::LegacyCGISession;

my $build_session = \&OpenXPKI::Client::Service::WebUI::_build_session;

################################################################################
# Mock helpers
################################################################################

{
    package MockConfig;
    sub new      { bless { data => $_[1] // {} }, $_[0] }
    sub get_hash { $_[0]->{data}{ $_[1] } }
    sub get      { $_[0]->{data}{ $_[1] } }
    sub exists   { exists $_[0]->{data}{ $_[1] } }
}

{
    package MockLog;
    sub new      { bless {}, shift }
    sub debug    { }
    sub info     { }
    sub trace    { }
    sub error    { }
    sub is_debug { 0 }
    sub is_trace { 0 }
}

# Minimal URL object so the OIDC path check ($self->normalized_request_url->path->parts->[-1])
# returns something other than 'oidc_redirect', sending _build_session down the
# normal cookie branch.
{
    package MockUrl;
    sub new   { bless {}, shift }
    sub path  { bless {}, 'MockUrl::Path' }
}
{
    package MockUrl::Path;
    sub parts { ['index'] }
}

{
    package MockSelf;
    sub new {
        my ($class, %args) = @_;
        return bless {
            config => $args{config} // MockConfig->new,
            log    => MockLog->new,
        }, $class;
    }
    sub config                 { $_[0]->{config} }
    sub log                    { $_[0]->{log} }
    sub normalized_request_url { MockUrl->new }
    # Throw so the try/catch in _build_session catches it and $id stays undef
    sub session_cookie         { die "no session cookie in test\n" }
}

################################################################################
# Empty session config -> LegacyCGISession
################################################################################

subtest 'Legacy session via empty config' => sub {
    my $session = $build_session->( MockSelf->new );

    isa_ok $session, 'OpenXPKI::Client::Service::WebUI::LegacyCGISession',
        'session';

    my $id = $session->id;
    ok $id, 'session has an ID';

    $session->param(probe => 1);
    $session->flush;

    ok -f "/tmp/cgisess_$id", 'session file exists in /tmp';

    unlink "/tmp/cgisess_$id";

    # With no cookie and no stored ID, each call produces a distinct new session
    my $s1 = $build_session->( MockSelf->new );
    my $s2 = $build_session->( MockSelf->new );

    isnt $s1->id, $s2->id, 'two empty-config sessions get distinct IDs';

    done_testing 4;
};

################################################################################
# session.params with a custom directory
################################################################################

subtest 'Legacy session with custom Directory' => sub {
    my $dir = tempdir( CLEANUP => 1 );

    my $cfg     = MockConfig->new({ 'session.params' => { Directory => $dir } });
    my $session = $build_session->( MockSelf->new( config => $cfg ) );
    my $id      = $session->id;

    ok $id, 'session has an ID';

    $session->param(probe => 1);
    $session->flush;

    ok -f "$dir/cgisess_$id", 'session file is in the configured directory';

    done_testing 2;
};

################################################################################
# Old config syntax: session.driver = 'driver:openxpki' -> Session object
################################################################################

subtest 'Old config syntax with session.driver=driver:openxpki' => sub {
    my $cfg = MockConfig->new({
        'session.driver' => 'driver:openxpki',
        'session.params' => {
            DataSource => 'dbi:mysql:database=oxi;host=db.local;port=3306',
            User       => 'oxiuser',
            Password   => 'oxipass',
        },
    });
    my $session = $build_session->( MockSelf->new( config => $cfg ) );

    isa_ok $session, 'OpenXPKI::Client::Service::WebUI::Session', 'session';

    my $p = $session->db_params;
    is $p->{type},   'MySQL',     'db type';
    is $p->{name},   'oxi',       'db name';
    is $p->{host},   'db.local',  'db host';
    is $p->{port},   '3306',      'db port';
    is $p->{user},   'oxiuser',   'db user';
    is $p->{passwd}, 'oxipass',   'db passwd';

    done_testing 7;
};

subtest 'Old config syntax with EncryptKey and LogIP' => sub {
    my $cfg = MockConfig->new({
        'session.driver' => 'driver:openxpki',
        'session.params' => {
            DataSource => 'dbi:mysql:database=oxi',
            EncryptKey => 'mykey',
            LogIP      => 1,
        },
    });
    my $session = $build_session->( MockSelf->new( config => $cfg ) );

    isa_ok $session, 'OpenXPKI::Client::Service::WebUI::Session', 'session';
    is  $session->encrypt_key, 'mykey', 'encrypt_key set on Session';
    ok  $session->log_ip,               'log_ip set on Session';

    done_testing 3;
};

################################################################################
# New config syntax: session.database -> Session object
################################################################################

subtest 'New config syntax: session.database' => sub {
    my $cfg = MockConfig->new({
        'session.database' => {
            type   => 'PostgreSQL',
            name   => 'oxi',
            host   => 'pghost',
            port   => 5432,
            user   => 'pguser',
            passwd => 'pgpass',
        },
    });
    my $session = $build_session->( MockSelf->new( config => $cfg ) );

    isa_ok $session, 'OpenXPKI::Client::Service::WebUI::Session', 'session';

    my $p = $session->db_params;
    is $p->{type},   'PostgreSQL', 'db type';
    is $p->{name},   'oxi',        'db name';
    is $p->{host},   'pghost',     'db host';
    is $p->{port},   5432,         'db port';
    is $p->{user},   'pguser',     'db user';
    is $p->{passwd}, 'pgpass',     'db passwd';

    done_testing 7;
};

subtest 'New config syntax: encrypt_key and log_ip' => sub {
    my $cfg = MockConfig->new({
        'session.database' => {
            type        => 'MySQL',
            name        => 'oxi',
            encrypt_key => 'secret',
            log_ip      => 1,
        },
    });
    my $session = $build_session->( MockSelf->new( config => $cfg ) );

    isa_ok $session, 'OpenXPKI::Client::Service::WebUI::Session', 'session';
    is  $session->encrypt_key, 'secret', 'encrypt_key set on Session';
    ok  $session->log_ip,                'log_ip set on Session';

    done_testing 3;
};

done_testing;
