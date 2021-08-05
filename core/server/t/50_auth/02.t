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

plan tests => 10;

my $ot = OpenXPKI::Test->new(
    with => "AuthLayer",
);


use_ok "OpenXPKI::Server::Authentication";

## load authentication configuration
my $auth;
lives_ok { $auth = OpenXPKI::Server::Authentication->new(); } "class loaded";

my @res;
lives_and {
    @res = $auth->login_step({
        STACK => 'Testing',
        MESSAGE => { PARAMS => {} }
    });
    ok ($res[0], 'Anonymous');
};

lives_and {
    @res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => {} }
    });
    cmp_deeply(\@res, superbagof({ 'SERVICE_MSG' => 'GET_PASSWD_LOGIN', PARAMS=> {} }));
};

note 'Fallthru';

lives_and {
    @res = $auth->login_step({
        STACK => 'FallThru',
        MESSAGE => { PARAMS => { username => 'foo' } },
    });
    cmp_deeply(\@res, superbagof('foo', 'Anonymous', { 'SERVICE_MSG' => 'SERVICE_READY' }));
};

lives_and {
    @res = $auth->login_step({
        STACK => 'FallThru',
        MESSAGE => { PARAMS => { username => 'foo', password => 'wrongsecret' } },
    });
    cmp_deeply(\@res, superbagof('foo', 'Anonymous', { 'SERVICE_MSG' => 'SERVICE_READY' }));
};

lives_and {
    @res = $auth->login_step({
        STACK => 'FallThru',
        MESSAGE => { PARAMS => { username => 'foo', password => 'secret' } },
    });
    cmp_deeply(\@res, superbagof('foo', 'User', { 'SERVICE_MSG' => 'SERVICE_READY' }));
};

note 'Password only';

lives_and {
    @res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => { username => 'foo' } },
    });
    cmp_deeply(\@res, superbagof({ 'SERVICE_MSG' => 'GET_PASSWD_LOGIN', PARAMS=> {} }));
};

throws_ok {
    @res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => { username => 'foo', password => 'wrongsecret' } },
    });
} qr/I18N_OPENXPKI_UI_AUTHENTICATION_FAILED/, "wrong secret";

lives_and {
    @res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => { username => 'foo', password => 'secret' } },
    });
    cmp_deeply(\@res, superbagof('foo', 'User', { 'SERVICE_MSG' => 'SERVICE_READY' }));
};

1;
