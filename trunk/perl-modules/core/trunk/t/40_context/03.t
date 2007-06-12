use strict;
use warnings;
use Test::More;
use Data::Dumper;
use Scalar::Util qw( blessed );

# use Smart::Comments;

use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

plan tests => 11;

diag "OpenXPKI::Server::Context - global context entries\n";

## init Context
ok(OpenXPKI::Server::Init::init(
       {
	   CONFIG => 't/config_test.xml',
	   TASKS  => [ 'current_xml_config', 
		       'i18n', 
               'dbi_log',
		       'log', 
#		       'redirect_stderr', 
		       'dbi_backend', 
		       'dbi_workflow',
               'xml_config',
		       'crypto_layer',
		       'pki_realm', 
		       'volatile_vault',
               'acl',
               'api',
               'authentication',
               ],
       }));


is(ref CTX('xml_config'), 
    'OpenXPKI::XML::Config', "CTX('xml_config')");

is(ref CTX('crypto_layer'),
    'OpenXPKI::Crypto::TokenManager', "CTX('crypto_layer')");

is(ref CTX('volatile_vault'),
   'OpenXPKI::Crypto::VolatileVault', "CTX('volatile_vault')");

is(ref CTX('log'),
    'OpenXPKI::Server::Log', "CTX('log')");

is(ref CTX('dbi_backend'),
   'OpenXPKI::Server::DBI', "CTX('dbi_backend')"
);

is(ref CTX('dbi_workflow'),
   'OpenXPKI::Server::DBI', "CTX('dbi_workflow')"
);

is(ref CTX('acl'),
   'OpenXPKI::Server::ACL', "CTX('acl')"
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
