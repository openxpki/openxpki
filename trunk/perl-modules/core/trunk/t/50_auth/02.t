use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 2 };

print STDERR "OpenXPKI::Server::Authentication\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config_test.xml',
	TASKS => [
        'current_xml_config',
        'log',
        'dbi_backend',
        'xml_config',
    ],
	SILENT => 1,
    });

## load authentication configuration
ok(OpenXPKI::Server::Authentication->new ());

1;
