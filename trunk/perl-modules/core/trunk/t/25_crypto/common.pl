# This is a hideous hack to provide all tests with a sensibly set up
# XML cache. This code is meant to be 'eval `cat ...`' from the calling
# test. Note that the tests are invoked from the top level directory,
# so all file references must take this into account.

use strict;
use warnings;
use English;
use OpenXPKI::Server::Context qw( CTX );
use File::Spec;
use OpenXPKI::FileUtils;
use OpenXPKI::Config::Test;
use OpenXPKI::Server::Session::Mock;
use OpenXPKI::Server::Log::NOOP;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Init;

our $basedir = File::Spec->catfile('t', '25_crypto');

foreach my $dir ("t/25_crypto/test-ca/tmp",                 
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
    api => OpenXPKI::Server::API->new(),
});

our $cacert;
my $cacertfile = "$basedir/test-ca/cacert.pem";
my $fu = OpenXPKI::FileUtils->new();
if (-e $cacertfile) { # if the CA certificate exists, make it available globally
                      # for use with CA tokens
  $cacert = $fu->read_file($cacertfile);
}
1;
