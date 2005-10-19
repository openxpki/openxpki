## OpenXPKI::Crypto::OpenSSL::Engine::OpenSSL.pm 
## Copyright (C) 2003-2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Engine::OpenSSL;

use base qw(OpenXPKI::Crypto::OpenSSL::Engine);

1;
__END__

=head1 Description

The real implementation is in OpenXPKI::Crypto::OpenSSL::Engine.
This engine is only a dummy to allow interface compliant usage of
the reference implementation. OpenXPKI::Crypto::OpenSSL::Engine
includes a basic specification of every function and an
implmentation which bases on OpenSSL software keys.
