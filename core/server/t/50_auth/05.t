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


plan tests => 20;

my $oxitest = OpenXPKI::Test->new(
    with => "AuthLayer",
    add_config => {
        "realm.test.auth.handler.NoAuthStaticRole" => {             
            role => "myrole"            
        },
        "realm.test.auth.handler.NoAuthWithRole" => {
        },
    }
);

use_ok "OpenXPKI::Server::Authentication::NoAuth";

my $auth;
note "Static role";
lives_ok {
    $auth = OpenXPKI::Server::Authentication::NoAuth->new('auth.handler.NoAuthStaticRole');
} "class loaded";

my $user = $auth->handleInput({});
ok (!defined $user);

$user = $auth->handleInput({ username => 'foo', role => 'ignore' });
ok (defined $user);

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
ok($user->username() eq 'foo');
ok($user->role() eq 'myrole');


note "Dynamic role";
lives_ok {
    $auth = OpenXPKI::Server::Authentication::NoAuth->new('auth.handler.NoAuthWithRole');
} "class loaded";

$user = $auth->handleInput({});
ok (!defined $user);

note 'missing role';
$user = $auth->handleInput({ username => 'foo'  });
ok (defined $user);

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok(!$user->is_valid());
is($user->username(), 'foo');
is($user->error(), OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED );

$user = $auth->handleInput({ username => 'foo', role => 'myrole' });
ok (defined $user);

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
is($user->username(), 'foo');
is($user->role(), 'myrole');
