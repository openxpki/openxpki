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

plan tests => 18;

my $ot = OpenXPKI::Test->new(
    with => "AuthLayer",
);
 

use_ok "OpenXPKI::Server::Authentication";

## load authentication configuration
my $auth;
lives_ok { $auth = OpenXPKI::Server::Authentication->new(); } "class loaded";

my @res = $auth->login_step({
    STACK => 'Testing',
    MESSAGE => { PARAMS => {} }
});
ok ($res[0], 'Anonymous');

@res = $auth->login_step({
    STACK => 'Password',
    MESSAGE => { PARAMS => {} }
});

note 'Fallthru';

is_deeply($res[2], { 'SERVICE_MSG' => 'GET_PASSWD_LOGIN', PARAMS=> {} });

@res = $auth->login_step({
    STACK => 'FallThru',
    MESSAGE => { PARAMS => { username => 'foo' } },
});

is_deeply($res[2], { 'SERVICE_MSG' => 'SERVICE_READY' });
is($res[0], 'foo');
is($res[1], 'Anonymous');

@res = $auth->login_step({
    STACK => 'FallThru',
    MESSAGE => { PARAMS => { username => 'foo', password => 'wrongsecret' } },
});

is_deeply($res[2], { 'SERVICE_MSG' => 'SERVICE_READY' });
is($res[0], 'foo');
is($res[1], 'Anonymous');

@res = $auth->login_step({
    STACK => 'FallThru',
    MESSAGE => { PARAMS => { username => 'foo', password => 'secret' } },
});

is_deeply($res[2], { 'SERVICE_MSG' => 'SERVICE_READY' });
is($res[0], 'foo');
is($res[1], 'User');


note 'Password only';

@res = $auth->login_step({
    STACK => 'Password',
    MESSAGE => { PARAMS => { username => 'foo' } },
});
is_deeply($res[2], { 'SERVICE_MSG' => 'GET_PASSWD_LOGIN', PARAMS=> {} });

throws_ok {
    @res = $auth->login_step({
        STACK => 'Password',
        MESSAGE => { PARAMS => { username => 'foo', password => 'wrongsecret' } },
    });
} qr/I18N_OPENXPKI_UI_AUTHENTICATION_FAILED/, "wrong secret";

@res = $auth->login_step({
    STACK => 'Password',
    MESSAGE => { PARAMS => { username => 'foo', password => 'secret' } },
});

is_deeply($res[2], { 'SERVICE_MSG' => 'SERVICE_READY' });
is($res[0], 'foo');
is($res[1], 'User');



1;
