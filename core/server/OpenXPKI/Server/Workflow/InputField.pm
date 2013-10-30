# OpenXPKI::Server::Workflow::InputField

package OpenXPKI::Server::Workflow::InputField;

use strict;
use base qw( Workflow::Action::InputField );

# extra action class properties
my @EXTRA_PROPS = qw( pos );
__PACKAGE__->mk_accessors(@EXTRA_PROPS);