use strict;
use warnings;
use English;
use Test::More;
plan tests => 8;

diag "OpenXPKI::Server::Authentication::Password\n";

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
require OpenXPKI::Server::Authentication;



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

## perform authentication
($user, $role, $reply) = $auth->login_step({
    STACK   => 'Foo',
    MESSAGE => {
        'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
        'PARAMS'      => {
            'LOGIN'  => 'Foo',
            'PASSWD' => 'Koxkz3rW',
        },
    },
});

ok($user eq 'Foo');
ok($reply->{'SERVICE_MSG'} eq 'SERVICE_READY');    



$auth = undef;
## load authentication configuration
$auth = OpenXPKI::Server::Authentication::Password->new ({
        XPATH   => ['pki_realm', 'auth', 'handler' ], 
        COUNTER => [ 0         , 0     , 2         ],
});
ok($auth);

## perform authentication
$user = undef;
$role = undef;
$reply = undef;

($user, $role, $reply) = $auth->login_step({
    STACK   => 'Operator',
    MESSAGE => {
        'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
        'PARAMS'      => {
            'LOGIN'  => 'root',
            'PASSWD' => 'root',
        },
    },
});


ok($user eq 'root');
ok($reply->{'SERVICE_MSG'} eq 'SERVICE_READY');    



1;
