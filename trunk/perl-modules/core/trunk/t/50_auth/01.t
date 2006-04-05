use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 24 };

print STDERR "OpenXPKI::Server::Session\n";

use OpenXPKI::Server::Session;
ok(1);

## create new session
my $session = OpenXPKI::Server::Session->new ({
                  DIRECTORY => "t/50_auth/",
                  LIFETIME  => 2});
ok($session);

## get ID
my $id = $session->get_id();
ok($id);

## check that is not valid
ok(!$session->is_valid());

## switch to authentication mode
ok($session->start_authentication());

## check that it is not valid
ok(!$session->is_valid());

## save challenge
my $challenge = "This is challenge.";
ok($session->set_challenge($challenge));

## DESTROY
undef $session;
ok(not defined $session);

## load
$session = OpenXPKI::Server::Session->new ({
               DIRECTORY => "t/50_auth/",
               LIFETIME  => 2,
               ID        => $id});
ok($session);

## check that it is not valid
ok(!$session->is_valid());

## get challenge
ok ($challenge eq $session->get_challenge());

## make it a valid session
ok ($session->make_valid());

## check that it is valid
ok($session->is_valid());

## DESTROY
undef $session;
ok(not defined $session);

## load
$session = OpenXPKI::Server::Session->new ({
               DIRECTORY => "t/50_auth/",
               LIFETIME  => 2,
               ID        => $id});
ok($session);

## check that it is valid
ok($session->is_valid());

## DESTROY
undef $session;
ok(not defined $session);

## wait five seconds to timeout
ok(sleep 2);

## try to load
eval {$session = OpenXPKI::Server::Session->new ({
                     DIRECTORY => "t/50_auth/",
                     LIFETIME  => 2,
                     ID        => $id});};
ok($EVAL_ERROR);

## create new session
$session = OpenXPKI::Server::Session->new ({
               DIRECTORY => "t/50_auth/",
               LIFETIME  => 2});
ok($session);
$id = $session->get_id();
ok($id);

## delete session
ok($session->delete());
undef $session;
ok(!-e "t/50_auth/cgisess_$id");

## try to load dropped session
eval {$session = OpenXPKI::Server::Session->new ({
                     DIRECTORY => "t/50_auth/",
                     LIFETIME  => 2,
                     ID        => $id});};
ok($EVAL_ERROR);

1;
