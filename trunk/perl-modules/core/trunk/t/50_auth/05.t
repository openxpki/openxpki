use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 7 };

print STDERR "OpenXPKI::Server::Authentication::External (dynamic role)\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Service::Test;
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

## create new test user interface
my $gui = OpenXPKI::Service::Test->new({
              "AUTHENTICATION_STACK" => "External Dynamic",
              "LOGIN"                => "John Doe",
              "PASSWD"               => "User"});
ok(OpenXPKI::Server::Context::setcontext ({"service" => $gui}));

## perform authentication
ok($auth->login ());

## check session
ok($session->is_valid());
ok($session->get_role() eq "User");

1;
