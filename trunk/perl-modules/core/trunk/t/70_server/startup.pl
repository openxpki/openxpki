use strict;
use warnings;

use OpenXPKI::Debug;

if (grep /^--debug$/, @ARGV)
{
    $OpenXPKI::Debug::LEVEL{'.*'} = 100;
    print STDERR "Starting server in full debug mode for all modules ...\n";
}

require OpenXPKI::Server;

OpenXPKI::Server->new ("CONFIG" => "t/config.xml");

1;
