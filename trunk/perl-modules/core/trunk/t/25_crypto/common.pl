# This is a hideous hack to provide all tests with a sensibly set up
# XML cache. This code is meant to be 'eval `cat ...`' from the calling
# test. Note that the tests are invoked from the top level directory,
# so all file references must take this into account.

use strict;
use warnings;
use English;
use OpenXPKI;
use OpenXPKI::Server::Context qw( CTX );
use File::Spec;
use OpenXPKI::FileUtils;
use OpenXPKI::Config::Test;
use OpenXPKI::Server::Session::Mock;
use OpenXPKI::Server::Log::NOOP;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Init;

our $basedir = File::Spec->catfile('t', '25_crypto');

foreach my $dir ("t/25_crypto/ca1/certs",
                 "t/25_crypto/ca2/certs",
                 "t/25_crypto/canciph/certs",
                 "t/25_crypto/cagost/certs")
{
    `mkdir -p $dir` if (not -d $dir);
}


## create context
OpenXPKI::Server::Context::setcontext({
    config => OpenXPKI::Config::Test->new(),
});

OpenXPKI::Server::Context::setcontext({
   log => OpenXPKI::Server::Log::NOOP->new(),
});


OpenXPKI::Server::Init::__do_init_api();
OpenXPKI::Server::Init::__do_init_dbi_backend();


# Create Mock session (necessary to get current realm)
my $session = OpenXPKI::Server::Session::Mock->new();
OpenXPKI::Server::Context::setcontext({'session' => $session});
$session->set_pki_realm('I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA');

our $cacert;
my $cacertfile = "$basedir/ca1/cacert.pem";
my $fu = OpenXPKI::FileUtils->new();
if (-e $cacertfile) { # if the CA certificate exists, make it available globally
                      # for use with CA tokens
  $cacert = $fu->read_file($cacertfile);
}
1;
