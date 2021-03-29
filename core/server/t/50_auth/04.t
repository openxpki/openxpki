#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

#use OpenXPKI::Debug; BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto::Secret.*'} = 100 }

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;


plan tests => 34;

my $oxitest = OpenXPKI::Test->new(
    with => "AuthLayer",
    add_config => {
        "realm.test.auth.handler.StaticRole" => { 
            role => "Static",
            user => {
                "foo" => '$5$e2O4wxv1gZZrPE8h$DuYmb/Z34jwj8FM47O6wvb4Gd5eBoj39j5kIHTEwZd.',
                "bar" => '$6$T9IOwQV6cvVY4oDR$pUBkEU6.vPpyHHVegQfc9AuJlGdq7IBpi/uIZ.OQ79Cjt.1bSMUFctE7yvy9rmTJ0up.4KvRSfgZ5paJATtMA/',
            },
        },
        "realm.test.auth.handler.DynamicRole" => {
            user => {
                "foo" => {
                    digest => '$5$e2O4wxv1gZZrPE8h$DuYmb/Z34jwj8FM47O6wvb4Gd5eBoj39j5kIHTEwZd.',
                    role => 'User',
                    realname => 'Mr. Foo',
                    emailaddress => 'foo@example.com',
                },
                "bar" => {
                    digest => '$1$Z4/J2mG7$85B0Ah9yV9W/aHubFcQMv.',
                    # no role -> must fail
                }
            },                        
        },
    }
);
 
use_ok "OpenXPKI::Server::Authentication::Password";
use_ok "OpenXPKI::Server::Authentication::Handle";

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication::Password->new ('auth.handler.StaticRole');
ok($auth);

note "empty login";
my $user = $auth->handleInput({});
ok (!defined $user);

note "unknown user";
$user = $auth->handleInput({
    username => 'alice',
    password => 'secret',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::USER_UNKNOWN );


note "known user, wrong password";
$user = $auth->handleInput({
    username => 'foo',
    password => 'secret',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED );

note "foo with password";
$user = $auth->handleInput({
    username => 'foo',
    password => 'openxpki',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
ok($user->username() eq 'foo');
ok($user->role() eq 'Static');

note "bar with password";
$user = $auth->handleInput({
    username => 'bar',
    password => 'openxpki',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
ok($user->username() eq 'bar');
ok($user->role() eq 'Static');

note 'Dynamic role';

$auth = OpenXPKI::Server::Authentication::Password->new ('auth.handler.DynamicRole');
ok($auth);

note "unknown user";
$user = $auth->handleInput({
    username => 'alice',
    password => 'secret',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::USER_UNKNOWN );


note "known user, wrong password";
$user = $auth->handleInput({
    username => 'foo',
    password => 'secret',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED );

note "foo with password";
$user = $auth->handleInput({
    username => 'foo',
    password => 'openxpki',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
is($user->username(), 'foo');
is($user->role(), 'User');
is_deeply($user->userinfo(), {realname => 'Mr. Foo', emailaddress => 'foo@example.com'});

note "bar (no role)";
$user = $auth->handleInput({
    username => 'bar',
    password => 'openxpki',
});

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok(!$user->is_valid());
is($user->username(), 'bar');
is($user->error(), OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED );

1;
