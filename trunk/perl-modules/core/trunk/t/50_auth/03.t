use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 5 };

print STDERR "OpenXPKI::Server::Authentication::Anonymous\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config.xml',
	TASKS => [ 'xml_config' ],
	SILENT => 1,
    });

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication->new ();
ok($auth);

## create new session
my $session = OpenXPKI::Server::Session->new ({
                  DIRECTORY => "t/50_auth/",
                  LIFETIME  => 5});
ok($session);
OpenXPKI::Server::Context::setcontext ({'session' => $session});

## set pki realm to identify configuration
$session->set_pki_realm ("Test Root CA");

## perform authentication
my ($user, $role, $reply) =  $auth->login_step({
    STACK   => 'Anonymous',
    MESSAGE => {},
});
ok(defined $user);
ok($reply->{'SERVICE_MSG'} eq 'SERVICE_READY');


1;
