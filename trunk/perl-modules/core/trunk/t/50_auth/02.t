use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 3 };

print STDERR "OpenXPKI::Server::Authentication\n";

use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## create context
use OpenXPKI::Server::Context qw( CTX );
### instantiating context...
ok(OpenXPKI::Server::Context::create(
       CONFIG => 't/config.xml',
       DEBUG  => 0,
   ));

## load authentication configuration
ok(OpenXPKI::Server::Authentication->new (
       DEBUG  => 0));

1;
