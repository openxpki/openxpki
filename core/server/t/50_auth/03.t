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


plan tests => 14;

my $oxitest = OpenXPKI::Test->new(
    with => "AuthLayer",
    add_config => {
        "realm.test.auth.handler.Anonymous" => { type => 'Anonymous' },
        "realm.test.auth.handler.AnonRole" => {
            name => "John Doe",
            role => "NotSoAnon"            
        },
    }
);


use_ok "OpenXPKI::Server::Authentication::Anonymous";

my $auth;
lives_ok {
    $auth = OpenXPKI::Server::Authentication::Anonymous->new('auth.handler.Anonymous');
} "class loaded";
ok (defined $auth);

my $user = $auth->handleInput({});
ok (defined $user);

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
ok($user->username() eq 'Anonymous');
ok($user->role() eq 'Anonymous');

$auth = OpenXPKI::Server::Authentication::Anonymous->new('auth.handler.AnonRole');
ok (defined $auth);

$user = $auth->handleInput({});
ok (defined $user);

is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
is_deeply($user->userinfo(), {realname => 'John Doe'});
ok($user->role() eq 'NotSoAnon');

1;
