## OpenXPKI::Crypto::Tool::PKCS7
## Written 2006 by Alexander Klink for the OpenXPKI project
## based on OpenXPKI::Crypto::Toolkit
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::PKCS7;
use base qw( OpenXPKI::Crypto::Toolkit );	

use strict;
use warnings;

use Class::Std;

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::PKCS7 - PKCS7 message backend

=head1 Description

This is the class to provide OpenXPKI with an interface to
openca-sv, the PKCS#7 tool from OpenCA

=head1 See Also

OpenXPKI::Crypto::Toolkit

