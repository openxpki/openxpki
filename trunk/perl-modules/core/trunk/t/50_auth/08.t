use strict;
use warnings;
use English;
use Test::More;
plan tests => 7;

diag "OpenXPKI::Server::ACL Performance\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::ACL;
ok(1);

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config.xml',
	TASKS => [
        'current_xml_config',
        'log',
        'dbi_backend',
        'xml_config',
    ],
	SILENT => 1,
    });

## create new session
my $session = OpenXPKI::Server::Session->new ({
                  DIRECTORY => "t/50_auth/",
                  LIFETIME  => 5});
ok($session);
ok(OpenXPKI::Server::Context::setcontext({'session' => $session}));

## configure the session
$session->set_pki_realm ("Test Root CA");
$session->set_role ("CA Operator");
$session->make_valid ();
ok($session->is_valid());

## initialize the ACL
my $acl = OpenXPKI::Server::ACL->new();
ok($acl);

## start the real ACL tests

my $items = 10000;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
   $acl->authorize ({ACTIVITYCLASS => "Test::Test",
                     ACTIVITY      => "Test::activity",
                     AFFECTED_ROLE => "User"});
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
diag " - $result checks/second (minimum: 10.000 per second)\n";
ok($result);

1;
