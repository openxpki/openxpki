use strict;
use warnings;
use English;
use Test::More;
plan tests => 6;

diag "OpenXPKI::Server::ACL Correctness\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::ACL;

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config.xml',
	TASKS => [ 'xml_config' ],
	SILENT => 1,
    });

## create new session
my $session = OpenXPKI::Server::Session->new ({
                  DIRECTORY => "t/50_auth/",
                  LIFETIME  => 5});
ok($session, 'Session object creation');
ok(OpenXPKI::Server::Context::setcontext({session => $session}), 'Set session in CTX');
ok(OpenXPKI::Server::Context::setcontext({
    log => OpenXPKI::Server::Log::NOOP->new()}),
    'Dummy log object in CTX');

## configure the session
$session->set_pki_realm ("Test Root CA");
$session->set_role ("CA Operator");
$session->make_valid ();
ok($session->is_valid(), 'Session made valid');

## initialize the ACL
my $acl = OpenXPKI::Server::ACL->new();
ok($acl, 'ACL object instantiated');

## start the real ACL tests

ok($acl->authorize ({ACTIVITYCLASS => "Test::Test",
                     ACTIVITY      => "Test::activity",
                     AFFECTED_ROLE => "User"}), 'authorize');

1;
