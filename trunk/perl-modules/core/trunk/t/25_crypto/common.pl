# This is a hideous hack to provide all tests with a sensibly set up
# XML cache. This code is meant to be 'eval `cat ...`' from the calling
# test. Note that the tests are invoked from the top level directory,
# so all file references must take this into account.

use strict;
use warnings;
use English;
use OpenXPKI;
use OpenXPKI::XML::Config;
use OpenXPKI::Server::Context qw( CTX );
use File::Spec;
use OpenXPKI::FileUtils;

our $cache;

our $basedir = File::Spec->catfile('t', '25_crypto');

foreach my $dir ("t/25_crypto/ca1/certs",
                 "t/25_crypto/ca2/certs",
                 "t/25_crypto/canciph/certs",
                 "t/25_crypto/cagost/certs")
{
    `mkdir -p $dir` if (not -d $dir);
}

$cache = eval { OpenXPKI::XML::Config->new(CONFIG => "t/config_test.xml") };
die $EVAL_ERROR."\n" if ($EVAL_ERROR and not ref $EVAL_ERROR);
die $EVAL_ERROR->as_string()."\n" if ($EVAL_ERROR);
die "Could not init XML config. Stopped" if (not $cache);

## create context
OpenXPKI::Server::Context::setcontext({
    xml_config => $cache,
});

our $cacert;
my $cacertfile = "$basedir/ca1/cacert.pem";
my $fu = OpenXPKI::FileUtils->new();
if (-e $cacertfile) { # if the CA certificate exists, make it available globally
                      # for use with CA tokens
  $cacert = $fu->read_file($cacertfile);
}
1;
