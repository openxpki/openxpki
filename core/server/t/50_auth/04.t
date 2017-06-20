use strict;
use warnings;
use English;
use Test::More skip_all => 'See Issue #188 [fix password access to travis-ci]';
#plan tests => 10;

note "OpenXPKI::Server::Authentication::Password\n";

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
require OpenXPKI::Server::Authentication;



## init XML cache
OpenXPKI::Server::Init::init(
    {
	TASKS => [
        'config_test',
        'log',
        'dbi',
    ],
	SILENT => 1,
    });

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication::Password->new ('auth.handler.User Password');
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


# Exisiting user - wrong password
eval {
($user, $role, $reply) = $auth->login_step({
    STACK   => 'Foo',
    MESSAGE => {
        'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
        'PARAMS'      => {
            'LOGIN'  => 'Foo',
            'PASSWD' => 'wrongpassword',
        },
    },
});
};
like($@, "/I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED/");


# Non-Exisiting user
eval {
($user, $role, $reply) = $auth->login_step({
    STACK   => 'Foo',
    MESSAGE => {
        'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
        'PARAMS'      => {
            'LOGIN'  => 'Bar',
            'PASSWD' => 'anything',
        },
    },
});
};
like($@, "/I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED/");


$auth = undef;
## load authentication configuration
$auth = OpenXPKI::Server::Authentication::Password->new ('auth.handler.Operator Password');
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
