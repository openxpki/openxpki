use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 7 };

print STDERR "OpenXPKI::Server::Authentication::Password\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Service::Test;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## init XML cache
my $xml = OpenXPKI::Server::Init->get_xml_config (CONFIG => 't/config.xml');

## create context
ok(OpenXPKI::Server::Context::setcontext({
       xml_config => $xml,
   }));

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

## create new test user interface
my $gui = OpenXPKI::Service::Test->new({
              "AUTHENTICATION_STACK" => "User",
              "LOGIN"                => "John Doe",
              "PASSWD"               => "Doe"});
ok(OpenXPKI::Server::Context::setcontext ({"service" => $gui}));

## perform authentication
eval {$auth->login ()};
if ($EVAL_ERROR)
{
    print STDERR "\$auth->login() failed: ${EVAL_ERROR}\n";
    ok(0);
} else {
    ok(1);
}

## check session
ok($session->is_valid());

1;
