use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 8 };

print STDERR "OpenXPKI::Server::Authentication::External (static role)\n";

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
       debug      => 0,
   }));

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication->new ({
               DEBUG  => 0});
ok($auth);

## create new session
my $session = OpenXPKI::Server::Session->new ({
                  DEBUG     => 0,
                  DIRECTORY => "t/50_auth/",
                  LIFETIME  => 5});
ok($session);
OpenXPKI::Server::Context::setcontext ({'session' => $session});

## set pki realm to identify configuration
$session->set_pki_realm ("Test Root CA");

## create new test user interface
my $gui = OpenXPKI::Service::Test->new({
           "DEBUG"                => 0,
           "AUTHENTICATION_STACK" => "External Static",
           "LOGIN"                => "John Doe",
           "PASSWD"               => "User"});
ok(OpenXPKI::Server::Context::setcontext ({"service" => $gui}));

## perform authentication
ok($auth->login ());

## check session
ok($session->is_valid());
ok($session->get_role() eq "RA Operator"); # see auth.xml

1;
