use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 6;

use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Config::Test;
use OpenXPKI::Config::Merge;

my $hash = 'dc3cc99137653d9f53f5721281e6ad77aee78234';

my $build_config = OpenXPKI::Config::Merge->new({
    dbpath => 't/config.git',
    path =>[ 't/config.d' ],    
});

# FIXME - need to compute the correct hash before
$hash = $build_config->version();

is($build_config->version(), $hash, 'Build Version ok');

my $config = OpenXPKI::Config::Test->new();

is($config->get_version(), $hash, 'Live Version ok');

is($config->get('system.realms.I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA.online'), '1', 'Test realm set online');
is($config->get('crypto.token.default.backend'),'OpenXPKI::Crypto::Backend::OpenSSL', 'Test realm token config found');

# Check if the Mock Objects work
is(ref CTX('log'), 'OpenXPKI::Server::Log::NOOP');
is(ref CTX('session'), 'OpenXPKI::Server::Session::Mock');
