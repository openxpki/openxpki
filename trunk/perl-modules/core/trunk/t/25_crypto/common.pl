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

our $cache;

our $basedir = File::Spec->catfile('t', '25_crypto');

$cache = eval { OpenXPKI::XML::Config->new(DEBUG  => 0,
                                           CONFIG => "t/config.xml") };
die $EVAL_ERROR."\n" if ($EVAL_ERROR and not ref $EVAL_ERROR);
die $EVAL_ERROR->as_string()."\n" if ($EVAL_ERROR);
die "Could not init XML config. Stopped" if (not $cache);

## create context
OpenXPKI::Server::Context::setcontext({
    xml_config => $cache,
    debug      => 0,
});

1;
