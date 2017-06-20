use strict;
use warnings;
use English;
use Test::More skip_all => 'See Issue #188 [fix password access to travis-ci]';
#plan tests => 4;

print STDERR "OpenXPKI::Server::Authentication::External (dynamic role)\n" if $ENV{VERBOSE};

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Authentication;

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
my $auth = OpenXPKI::Server::Authentication::External->new("auth.handler.External Dynamic Role");
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
