use strict;
use warnings;

# Core modules
use File::Temp qw( tempdir );
use English;

# CPAN modules
use Test::More;
use Test::Exception;

plan tests => 20;

use_ok "OpenXPKI::Server::Session";

my $session_dir = tempdir( CLEANUP => 1 );

## create new session
my $session;
lives_ok {
    $session = OpenXPKI::Server::Session->new({
        DIRECTORY => $session_dir,
        LIFETIME  => 2,
        VERSION   => 'ignored',
    });
} "create session 1";

my $challenge = "This is challenge.";

## get ID
my $id = $session->get_id;
ok $id, "session ID exists";

isnt       $session->is_valid, 1,                   "session is still invalid";
lives_ok { $session->start_authentication }         "start authentication phase";
isnt       $session->is_valid, 1,                   "session is still invalid";
lives_ok { $session->set_challenge($challenge) }    "store challenge string";

note "destroy session 1 object";
undef $session;

## load existing session
lives_ok {
    $session = OpenXPKI::Server::Session->new ({
        DIRECTORY => $session_dir,
        LIFETIME  => 2,
        ID        => $id,
    });
} "load previously persisted session 1";

isnt       $session->is_valid, 1,                   "session is still invalid";
is         $session->get_challenge, $challenge,     "challenge is the same as before persisting";
lives_ok { $session->make_valid }                   "define session as valid";
is         $session->is_valid, 1,                   "session is valid";

note "destroy session 1 object";
undef $session;

## load
lives_ok {
    $session = OpenXPKI::Server::Session->new ({
        DIRECTORY => $session_dir,
        LIFETIME  => 2,
        ID        => $id,
    });
} "load previously persisted session 1 again";

is $session->is_valid, 1, "session is valid";

note "destroy session 1 object";
undef $session;

note "wait to exceed session lifetime";
ok(sleep 3);

## try to load
throws_ok {
    $session = OpenXPKI::Server::Session->new ({
        DIRECTORY => $session_dir,
        LIFETIME  => 2,
        ID        => $id,
    });
} qr/load.*fail/i, "attempt to load persisted session 1 fails because of exceeded session lifetime";

#diag `cat t/50_auth/cgisess_$id`;

## create new session
lives_ok {
    $session = OpenXPKI::Server::Session->new({
        DIRECTORY => $session_dir,
        LIFETIME  => 2,
        VERSION   => 'ignored',
    });
} "create session 2";

my $id2 = $session->get_id;
isnt $id2, $id, "session 2 id differs from 1 id";

## delete session
lives_ok { $session->delete } "delete (i.e. close) session";

note "destroy session 2 object";
undef $session;

## try to load dropped session
throws_ok {
    $session = OpenXPKI::Server::Session->new ({
        DIRECTORY => $session_dir,
        LIFETIME  => 2,
        ID        => $id2,
    });
} qr/load.*fail/i, "attempt to load persisted session 2 fails because it was deleted";

1;
