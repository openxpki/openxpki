use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../..";

use Test::More;
use Test::Exception;
use Test::Deep ':v1';

# Load only the parsing functions - no full WebUI object needed
require OpenXPKI::Client::Service::WebUI;
OpenXPKI::Client::Service::WebUI->import;

# Shortcuts to the private functions under test
my $parse_new = \&OpenXPKI::Client::Service::WebUI::_parse_new_session_config;
my $parse_old = \&OpenXPKI::Client::Service::WebUI::_parse_old_session_config;

################################################################################
# New config syntax: session.database
################################################################################

subtest 'New syntax: minimal PostgreSQL config' => sub {
    my ($db, $enc, $lip) = $parse_new->({
        type => 'PostgreSQL',
        name => 'oxi',
        host => 'db.example.com',
        port => 5432,
    });

    cmp_deeply $db, {
        type => 'PostgreSQL',
        name => 'oxi',
        host => 'db.example.com',
        port => 5432,
    }, 'db_params correct';
    is $enc, undef, 'no encrypt_key';
    is $lip, undef, 'no log_ip';

    done_testing 3;
};

subtest 'New syntax: session-specific keys are extracted' => sub {
    my ($db, $enc, $lip) = $parse_new->({
        type        => 'MySQL',
        name        => 'oxi',
        encrypt_key => 'secret',
        log_ip      => 1,
    });

    is $enc, 'secret',  'encrypt_key extracted';
    is $lip, 1,         'log_ip extracted';
    ok !exists $db->{encrypt_key}, 'encrypt_key not in db_params';
    ok !exists $db->{log_ip},      'log_ip not in db_params';

    done_testing 4;
};

subtest 'New syntax: password is alias for passwd' => sub {
    my ($db) = $parse_new->({
        type     => 'MySQL',
        name     => 'oxi',
        password => 's3cr3t',
    });

    is $db->{passwd}, 's3cr3t', 'password aliased to passwd';
    ok !exists $db->{password}, 'password key removed';

    done_testing 2;
};

subtest 'New syntax: passwd takes precedence over password' => sub {
    my ($db) = $parse_new->({
        type     => 'MySQL',
        name     => 'oxi',
        passwd   => 'first',
        password => 'second',
    });

    is $db->{passwd}, 'first', 'passwd wins over password';
    ok !exists $db->{password}, 'password key removed';

    done_testing 2;
};

subtest 'New syntax: namespace passes through to db_params' => sub {
    my ($db) = $parse_new->({
        type      => 'Oracle',
        name      => 'oxi',
        namespace => 'myschema',
    });

    is $db->{namespace}, 'myschema', 'namespace stays in db_params';

    done_testing 1;
};

################################################################################
# Old config syntax: session.driver + DataSource
################################################################################

subtest 'Old syntax: MySQL DataSource, key=value only' => sub {
    my ($db, $enc, $lip) = $parse_old->({
        DataSource => 'dbi:mysql:database=oxi;host=db.local;port=3306',
        User       => 'oxiuser',
        Password   => 'oxipass',
    });

    cmp_deeply $db, superhashof({
        type   => 'MySQL',
        name   => 'oxi',
        host   => 'db.local',
        port   => '3306',
        user   => 'oxiuser',
        passwd => 'oxipass',
    }), 'db_params correct';
    ok !exists $db->{dbi}, 'no leftover dbi key';
    is $enc, undef, 'no encrypt_key';
    is $lip, undef, 'no log_ip';

    done_testing 4;
};

subtest 'Old syntax: PostgreSQL with Pg driver name (case insensitive)' => sub {
    my ($db) = $parse_old->({
        DataSource => 'dbi:Pg:dbname=oxi;host=pghost',
    });

    is $db->{type}, 'PostgreSQL', 'Pg mapped to PostgreSQL';
    is $db->{name}, 'oxi',        'dbname alias works';
    is $db->{host}, 'pghost',     'host parsed';

    done_testing 3;
};

subtest 'Old syntax: SQLite with db= alias' => sub {
    my ($db) = $parse_old->({
        DataSource => 'dbi:SQLite:db=/tmp/test.db',
    });

    is $db->{type}, 'SQLite',        'SQLite type';
    is $db->{name}, '/tmp/test.db',  'db alias works';

    done_testing 2;
};

subtest 'Old syntax: EncryptKey and LogIP extracted' => sub {
    my ($db, $enc, $lip) = $parse_old->({
        DataSource => 'dbi:mysql:database=oxi',
        EncryptKey => 'mykey',
        LogIP      => 1,
    });

    is $enc, 'mykey', 'EncryptKey extracted';
    is $lip, 1,       'LogIP extracted';
    ok !exists $db->{EncryptKey}, 'EncryptKey not in db_params';
    ok !exists $db->{LogIP},      'LogIP not in db_params';

    done_testing 4;
};

subtest 'Old syntax: NameSpace passed through' => sub {
    my ($db) = $parse_old->({
        DataSource => 'dbi:Oracle:database=oxi',
        NameSpace  => 'myschema',
    });

    is $db->{namespace}, 'myschema', 'NameSpace -> namespace';
    ok !exists $db->{NameSpace}, 'NameSpace key removed';

    done_testing 2;
};

subtest 'Old syntax: unknown DSN key=value pairs go to dbi.dsn_extra' => sub {
    my ($db) = $parse_old->({
        DataSource => 'dbi:mysql:database=oxi;charset=utf8;connect_timeout=10',
    });

    ok exists $db->{dbi}, 'dbi key present';
    like $db->{dbi}{dsn_extra}, qr/charset=utf8/,         'charset in dsn_extra';
    like $db->{dbi}{dsn_extra}, qr/connect_timeout=10/,   'connect_timeout in dsn_extra';
    unlike $db->{dbi}{dsn_extra}, qr/database=/,          'database not in dsn_extra';

    done_testing 4;
};

subtest 'Old syntax: bare token (no equal sign) in DataSource' => sub {
    # Oracle TNS-style: dbi:Oracle:MYDB  (bare service name, no key=value)
    my ($db) = $parse_old->({
        DataSource => 'dbi:Oracle:MYDB',
    });

    is $db->{type}, 'Oracle', 'Oracle type';
    is $db->{name}, undef,    'no key=value database param';
    ok exists $db->{dbi},     'dbi key present for bare token';
    is $db->{dbi}{dsn_extra}, 'MYDB', 'bare token preserved in dsn_extra';

    done_testing 4;
};

subtest 'Old syntax: multiple bare tokens mixed with key=value' => sub {
    my ($db) = $parse_old->({
        DataSource => 'dbi:Oracle:MYDB;SERVICE_NAME=mypdb;mode=sysdba',
    });

    is $db->{type}, 'Oracle', 'Oracle type';
    is $db->{dbi}{dsn_extra}, 'MYDB;SERVICE_NAME=mypdb;mode=sysdba',
        'bare token comes first, then key=value pairs sorted';

    done_testing 2;
};

subtest 'Old syntax: bare tokens only (no key=value at all)' => sub {
    my ($db) = $parse_old->({
        DataSource => 'dbi:SQLite:foo;bar;baz',
    });

    is $db->{dbi}{dsn_extra}, 'foo;bar;baz', 'all bare tokens preserved';

    done_testing 1;
};

subtest 'Old syntax: dbi_connect_attrs passed through' => sub {
    my ($db) = $parse_old->({
        DataSource       => 'dbi:mysql:database=oxi',
        dbi_connect_attrs => { mysql_ssl => 1, mysql_ssl_ca_file => '/etc/ssl/ca.pem' },
    });

    cmp_deeply $db->{dbi}{attrs}, { mysql_ssl => 1, mysql_ssl_ca_file => '/etc/ssl/ca.pem' },
        'dbi_connect_attrs stored under dbi.attrs';

    done_testing 1;
};

subtest 'Old syntax: dbi_connect_attrs merged with dsn_extra' => sub {
    my ($db) = $parse_old->({
        DataSource        => 'dbi:mysql:database=oxi;charset=utf8',
        dbi_connect_attrs => { mysql_ssl => 1 },
    });

    is   $db->{dbi}{dsn_extra},       'charset=utf8', 'dsn_extra present';
    cmp_deeply $db->{dbi}{attrs}, { mysql_ssl => 1 },  'attrs present';

    done_testing 2;
};

subtest 'Old syntax: passwd alias from conf' => sub {
    my ($db) = $parse_old->({
        DataSource => 'dbi:mysql:database=oxi',
        passwd     => 'frompasswd',
    });

    is $db->{passwd}, 'frompasswd', 'passwd key accepted';

    done_testing 1;
};

################################################################################
# Error cases
################################################################################

subtest 'Error: no session.database and missing DataSource' => sub {
    throws_ok {
        $parse_old->({});
    } qr/missing 'DataSource'/, 'missing DataSource dies';

    done_testing 1;
};

subtest 'Error: unparseable DataSource' => sub {
    throws_ok {
        $parse_old->({
            DataSource => 'notadbi',
        });
    } qr/cannot parse DataSource/, 'bad DataSource format dies';

    done_testing 1;
};

subtest 'Error: unsupported DBI driver' => sub {
    throws_ok {
        $parse_old->({
            DataSource => 'dbi:DB2:database=oxi',
        });
    } qr/unsupported DBI driver 'DB2'/, 'unknown driver dies';

    done_testing 1;
};

done_testing;
