use strict;
use warnings;
use English;
use Test::More;
plan tests => 3;

diag "OpenXPKI::Server::Authentication::Anonymous\n" if $ENV{VERBOSE};

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## init XML cache
OpenXPKI::Server::Init::init(
    {	
	TASKS => [
        'config_test',
        'log',
        'dbi_backend',
    ],
	SILENT => 1,
    });

my $auth = OpenXPKI::Server::Authentication::Anonymous->new('auth.handler.Anonymous');
# perform authentication
my ($user, $role, $reply) =  $auth->login_step({
    STACK   => 'Anonymous',
    MESSAGE => {},
});
ok(defined $user);
ok($reply->{'SERVICE_MSG'} eq 'SERVICE_READY');

1;
