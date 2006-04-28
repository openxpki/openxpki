use strict;
use warnings;
use Test;
use Data::Dumper;
use Scalar::Util qw( blessed );

# use Smart::Comments;

use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Server::Context - global context entries\n";
ok(1);

## init Context
ok(OpenXPKI::Server::Init::init ({
       CONFIG => 't/config.xml',
   }));


ok(blessed CTX('xml_config'),
   'OpenXPKI::XML::Config');

ok(blessed CTX('crypto_layer'),
   'OpenXPKI::Crypto::TokenManager');

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

eval {
    CTX('server');
};
if (my $exc = OpenXPKI::Exception->caught()) {
    ok($exc->message(), 
       "I18N_OPENXPKI_SERVER_CONTEXT_CTX_OBJECT_NOT_DEFINED"); # expected error
} else {
    ok(0);
}


1;
