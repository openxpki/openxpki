use strict;
use warnings;
use English;
use Test::More skip_all => 'See Issue #188 [fix password access to travis-ci]';
#BEGIN { plan tests => 2 };

print STDERR "OpenXPKI::Server::Authentication\n" if $ENV{VERBOSE};

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Authentication;
ok(1);


## create context

## init XML cache
OpenXPKI::Server::Init::init(
    {
	TASKS => [
	    'config_test',
        'log',
        'dbi',
    ],
	SILENT => 1,
    });

## load authentication configuration
ok(OpenXPKI::Server::Authentication->new ());

1;
