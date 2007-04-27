use strict;
use warnings;
use English;
use Test::More;
plan tests => 3;

diag "OpenXPKI::Server::Authentication::Password\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config.xml',
	TASKS => [ 'xml_config' ],
	SILENT => 1,
    });

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication::Password->new ({
        XPATH   => ['pki_realm', 'auth', 'handler' ], 
        COUNTER => [ 0         , 0     , 1         ],
});
ok($auth);

## perform authentication
my ($user, $role, $reply) = $auth->login_step({
    STACK   => 'User',
    MESSAGE => {
        'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
        'PARAMS'      => {
            'LOGIN'  => 'John Doe',
            'PASSWD' => 'Doe',
        },
    },
});

ok($user eq 'John Doe');
ok($reply->{'SERVICE_MSG'} eq 'SERVICE_READY');    


1;
