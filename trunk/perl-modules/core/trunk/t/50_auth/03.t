use strict;
use warnings;
use English;
use Test::More;
plan tests => 3;

diag "OpenXPKI::Server::Authentication::Anonymous\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config_test.xml',
	TASKS => [
        'current_xml_config',
        'log',
        'dbi_backend',
        'xml_config',
    ],
	SILENT => 1,
    });

my $auth = OpenXPKI::Server::Authentication::Anonymous->new({
        XPATH   => ['pki_realm', 'auth', 'handler' ], 
        COUNTER => [ 0         , 0     , 0         ],
});
# perform authentication
my ($user, $role, $reply) =  $auth->login_step({
    STACK   => 'Anonymous',
    MESSAGE => {},
});
ok(defined $user);
ok($reply->{'SERVICE_MSG'} eq 'SERVICE_READY');

1;
