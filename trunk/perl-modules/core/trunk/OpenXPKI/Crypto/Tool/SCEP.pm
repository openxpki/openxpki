## OpenXPKI::Crypto::Tool::SCEP
## Written 2006 by Alexander Klink for the OpenXPKI project
## based on OpenXPKI::Crypto::Toolkit
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::SCEP;
use base qw( OpenXPKI::Crypto::Toolkit );	

use strict;
use warnings;

use Class::Std;

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::SCEP - SCEP message backend

=head1 Description

This is the class to provide OpenXPKI with an interface to
openca-scep.

=head1 See Also

OpenXPKI::Crypto::Toolkit

