use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 3 };

print STDERR "OpenXPKI::Server::Authentication\n";

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## init XML cache
my $xml = OpenXPKI::Server::Init->get_xml_config (CONFIG => 't/config.xml');

## create context
ok(OpenXPKI::Server::Context::setcontext({
       xml_config => $xml,
       debug      => 0,
   }));

## load authentication configuration
ok(OpenXPKI::Server::Authentication->new ({
       DEBUG  => 0}));

1;
