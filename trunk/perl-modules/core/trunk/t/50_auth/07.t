use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 6 };

print STDERR "OpenXPKI::Server::ACL Correctness\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::ACL;
ok(1);

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config.xml',
	TASKS => [ 'xml_config' ],
    });

## create new session
my $session = OpenXPKI::Server::Session->new ({
                  DIRECTORY => "t/50_auth/",
                  LIFETIME  => 5});
ok($session);
ok(OpenXPKI::Server::Context::setcontext({session => $session}));

## configure the session
$session->set_pki_realm ("Test Root CA");
$session->set_role ("CA Operator");
$session->make_valid ();
ok($session->is_valid());

## initialize the ACL
my $acl = OpenXPKI::Server::ACL->new();
ok($acl);

## start the real ACL tests

ok($acl->authorize ({ACTIVITYCLASS => "Test::Test",
                     ACTIVITY      => "Test",
                     AFFECTED_ROLE => "User"}));

1;
