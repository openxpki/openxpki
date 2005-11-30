use strict;
use warnings;

use OpenXPKI::Server;

OpenXPKI::Server->new ("CONFIG" => "t/config.xml",
                       "DEBUG"  => 0);

1;
