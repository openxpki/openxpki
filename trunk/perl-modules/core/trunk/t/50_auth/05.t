use strict;
use warnings;
use English;
use Test::More;
plan tests => 4;

print STDERR "OpenXPKI::Server::Authentication::External (dynamic role)\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;

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

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication::External->new({
        XPATH   => ['pki_realm', 'auth', 'handler' ], 
        COUNTER => [ 0         , 0     , 3         ],
});
ok($auth, 'Auth object creation');

my ($user, $role, $reply) = $auth->login_step({
    STACK   => 'External Dynamic',
    MESSAGE => {
        'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
        'PARAMS'      => {
            'LOGIN'  => 'John Doe',
            'PASSWD' => 'User',
        },
    },
});

is($user, 'John Doe', 'Correct user');
is($role, 'User', 'Correct role');
is($reply->{'SERVICE_MSG'}, 'SERVICE_READY', 'Service ready.');    

1;
