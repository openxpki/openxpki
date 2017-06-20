use strict;
use warnings;
use English;
use Test::More skip_all => 'See Issue #188 [fix password access to travis-ci]';
#plan tests => 3;

note "OpenXPKI::Server::Authentication::Anonymous\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Authentication;
ok(1);

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

my $auth = OpenXPKI::Server::Authentication::Anonymous->new('auth.handler.Anonymous');
# perform authentication
my ($user, $role, $reply) =  $auth->login_step({
    STACK   => 'Anonymous',
    MESSAGE => {},
});
ok(defined $user);
ok($reply->{'SERVICE_MSG'} eq 'SERVICE_READY');

1;
