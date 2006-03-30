use strict;
use warnings;
use Test;
use Data::Dumper;
use Scalar::Util qw( blessed );

use Smart::Comments;

use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

BEGIN { plan tests => 12 };

print STDERR "OpenXPKI::Server::Context - global context entries\n";
ok(1);

## init Context
my $debug = 0;
ok(OpenXPKI::Server::Init->new ({
       CONFIG => 't/config.xml',
       DEBUG  => $debug,
   }));


ok(blessed CTX('xml_config'),
   'OpenXPKI::XML::Config');

ok(blessed CTX('crypto_layer'),
   'OpenXPKI::Crypto::TokenManager');

ok(CTX('debug'),
   $debug);

ok(blessed CTX('log'),
   'OpenXPKI::Server::Log');

ok(blessed CTX('dbi_backend'),
   'OpenXPKI::Server::DBI');

ok(blessed CTX('dbi_workflow'),
   'OpenXPKI::Server::DBI');

ok(blessed CTX('acl'),
   'OpenXPKI::Server::ACL');

ok(blessed CTX('api'),
   'OpenXPKI::Server::API');

ok(blessed CTX('authentication'),
   'OpenXPKI::Server::Authentication');

ok(CTX('server'),
   undef);


1;
