use strict;
use warnings;

use Test::More;
use Test::Exception;
use Module::Load;

#
# Test legacy usage in custom code:
#
#     use OpenXPKI::Server::Database; # to get AUTO_ID
#

dies_ok { AUTO_ID() } 'AUTO_ID not available initially';

Module::Load::autoload('OpenXPKI::Server::Database');

is ref AUTO_ID(), 'OpenXPKI::Database::AUTOINCREMENT', 'AUTO_ID available after "use OpenXPKI::Server::Database"';

done_testing 2;
