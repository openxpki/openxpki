use strict;
use warnings;
use Test::More skip_all => 'See Issue #188 [fix password access to travis-ci]';
use Data::Dumper;
use Scalar::Util qw( blessed );

# use Smart::Comments;

use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

#plan tests => 10;

note "OpenXPKI::Server::Context - global context entries\n";

$ENV{OPENXPKI_CONF_DB} = 't/config.git/';

## init Context
ok(OpenXPKI::Server::Init::init(
       {
	   TASKS  => [
                'api',
               'config_versioned',
		       'i18n',
               'dbi_log',
		       'log',
		       'dbi',
		       'crypto_layer',
		       'volatile_vault',
#               'acl',
               'authentication',
               ],
       }));


is(ref CTX('config'),
    'OpenXPKI::Config', "CTX('config')");

is(ref CTX('crypto_layer'),
    'OpenXPKI::Crypto::TokenManager', "CTX('crypto_layer')");

is(ref CTX('volatile_vault'),
   'OpenXPKI::Crypto::VolatileVault', "CTX('volatile_vault')");

is(ref CTX('log'),
    'OpenXPKI::Server::Log', "CTX('log')");

is(ref CTX('dbi'),
   'OpenXPKI::Server::Database', "CTX('dbi')"
);

is(ref CTX('api'),
   'OpenXPKI::Server::API', "CTX('api')"
);

is(ref CTX('authentication'),
   'OpenXPKI::Server::Authentication', "CTX('authentication')"
);

eval {
    CTX('server');
};
my $exc = OpenXPKI::Exception->caught();
is($exc->message(), "I18N_OPENXPKI_SERVER_CONTEXT_CTX_OBJECT_NOT_DEFINED", 'Undefined object -> exception'); # expected error

1;
