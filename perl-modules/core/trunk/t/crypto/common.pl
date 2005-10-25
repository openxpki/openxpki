# This is a hideous hack to provide all tests with a sensibly set up
# XML cache. This code is meant to be 'eval `cat ...`' from the calling
# test. Note that the tests are invoked from the top level directory,
# so all file references must take this into account.

use OpenXPKI;
use OpenXPKI::XML::Config;

## init the XML cache
my $tokenconfigfile = File::Spec->catfile('t', 'crypto', 'token.xml');

# slurp in configuration file
my $config = OpenXPKI->read_file($tokenconfigfile) 
    or die "Could not read config file $tokenconfigfile. Stopped";

# set correct OpenSSL binary in configuration
my $openssl_binary = `cat t/cfg.binary.openssl`;

$config =~ s{ (<name>SHELL</name>\s*
               <value>) (.*?) (</value>) }
            {$1$openssl_binary$3}sx;

$cache = OpenXPKI::XML::Config->new(DEBUG  => 0,
                                    CONFIG => $config);

die "Could not init XML config. Stopped" if (not $cache);
