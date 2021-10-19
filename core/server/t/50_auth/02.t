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
use OpenXPKI::Debug;

#$OpenXPKI::Debug::BITMASK{'.*'} = 127;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;

use OpenXPKI::Server::Context qw( CTX );



use OpenXPKI::Server::Authentication;

plan tests => 29;

my $ot = OpenXPKI::Test->new(
    with => "AuthLayer",
);


use_ok "OpenXPKI::Server::Authentication";

## load authentication configuration
my $auth;
lives_ok { $auth = OpenXPKI::Server::Authentication->new(); } "class loaded";

my $res;
lives_and {
    $res = $auth->login_step({
        STACK => 'Testing',
        MESSAGE => { PARAMS => {} }
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->userid, 'Anonymous');
};

lives_and {
    $res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => {} }
    });
    cmp_deeply($res, { 'type' => 'passwd', params => {} });
};

note 'Fallthru';

lives_and {
    $res = $auth->login_step({
        STACK => 'FallThru',
        MESSAGE => { PARAMS => { username => 'foo' } },
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->userid, 'foo');
    is($res->role, 'Anonymous');
};

lives_and {
    $res = $auth->login_step({
        STACK => 'FallThru',
        MESSAGE => { PARAMS => { username => 'foo', password => 'wrongsecret' } },
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->userid, 'foo');
    is($res->role, 'Anonymous');
};

lives_and {
    $res = $auth->login_step({
        STACK => 'FallThru',
        MESSAGE => { PARAMS => { username => 'foo', password => 'secret' } },
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->userid, 'foo');
    is($res->role, 'User');
};

note 'Password only';

lives_and {
    $res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => { username => 'foo' } },
    });
    cmp_deeply($res, { 'type' => 'passwd', params => {} });
};

throws_ok {
    $res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => { username => 'foo', password => 'wrongsecret' } },
    });
} qr/I18N_OPENXPKI_UI_AUTHENTICATION_FAILED/, "wrong secret";

lives_and {
    $res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => { username => 'foo', password => 'secret' } },
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->userid, 'foo');
    is($res->role, 'User');
};

note 'Password with Tenant';
lives_and {
    $res = $auth->login_step({
        STACK => 'Tenant',
        MESSAGE => { PARAMS => { username => 'foo', password => 'secret' } },
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->role, 'User');
    cmp_deeply($res->tenant, ['Tenant A']);
};

lives_and {
    $res = $auth->login_step({
        STACK => 'Tenant',
        MESSAGE => { PARAMS => { username => 'bar', password => 'secret' } },
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->role, 'Operator');
    cmp_deeply($res->tenant, ['']);
};

lives_and {
    $res = $auth->login_step({
        STACK => 'Tenant',
        MESSAGE => { PARAMS => { username => 'guest', password => 'secret' } },
    });
    ok(ref $res eq 'OpenXPKI::Server::Authentication::Handle');
    is($res->userid, 'guest');
    is($res->role, 'Anonymous');
    ok(!$res->has_tenant());
};




1;
