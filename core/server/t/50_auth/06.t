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
use OpenXPKI::Server::Authentication::Handle;

use File::Basename;
my $dirname = dirname(__FILE__);

plan tests => 31;

ok (-e "$dirname/test.sh");
chmod 0755, "$dirname/test.sh";

my $oxitest = OpenXPKI::Test->new(
    with => "AuthLayer",
    add_config => {
        "realm.test.auth.handler.ExtStaticTrue" => { 
            command => '/bin/true',
            role => 'TrueRole',
        },
        "realm.test.auth.handler.ExtStaticFalse" => {
            command => '/bin/false',
            role => 'TrueRole',
        },
        "realm.test.auth.handler.ExtDynamic" => { 
            command => "$dirname/test.sh",
            env => {
                OPENXPKI_AUTH => '[% username %] : [% role %]'
            },
            output_template => '[% out.split(":").1 %]'
        },
        "realm.test.auth.handler.ExtDirectRole" => { 
            command => "$dirname/test.sh",
            env => {
                OPENXPKI_ROLE => '[% role %]'
            },            
        },
    }
);

use_ok "OpenXPKI::Server::Authentication::Command";

my $auth;
lives_ok {
    $auth = OpenXPKI::Server::Authentication::Command->new('auth.handler.ExtStaticTrue');
} "class loaded";
ok (defined $auth);

my $user = $auth->handleInput({});
ok (!defined $user);


$user = $auth->handleInput({ username => 'foo', password => 'secret' });
ok (defined $user);
is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok($user->is_valid());
is($user->username(), 'foo');
is($user->role(), 'TrueRole');
 

lives_and {
    $auth = OpenXPKI::Server::Authentication::Command->new('auth.handler.ExtStaticFalse');
    ok (defined $auth);
} "ExtStaticFalse";
$user = $auth->handleInput({});
ok (!defined $user);

$user = $auth->handleInput({ username => 'foo', password => 'secret' });
ok (defined $user);
is(ref $user, 'OpenXPKI::Server::Authentication::Handle');
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED );

lives_and {
    $auth = OpenXPKI::Server::Authentication::Command->new('auth.handler.ExtDynamic');
    ok (defined $auth);
} "ExtDynamic";

$user = $auth->handleInput({});
ok (!defined $user);

note 'false return / user not found';
$user = $auth->handleInput({ username => 'foo', password => 'secret' });
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED );


note 'login match but returned role is not defined';
$user = $auth->handleInput({ username => 'foobar', role => 'secret' });
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED );

note 'login and role should match';
# the test setup maps is somewhat artifical but should prove proper input 
# and output templating
$user = $auth->handleInput({ username => 'foobar', role => 'User' });

ok($user->is_valid());
is($user->username(), 'foobar');
is($user->role(), 'User');


lives_and {
    $auth = OpenXPKI::Server::Authentication::Command->new('auth.handler.ExtDirectRole');
    ok (defined $auth);
} "ExtDirectRole";
 
note 'false return / user not found';
$user = $auth->handleInput({ username => 'foo', password => 'secret' });
ok(!$user->is_valid());
is($user->error(), OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED );

note 'login and role matches';
$user = $auth->handleInput({ username => 'foobar', role => 'User' });
ok($user->is_valid());
is($user->username(), 'foobar');
is($user->role(), 'User');


1;
