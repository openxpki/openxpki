## OpenXPKI::Crypto::Backend::OpenSSL::Engine::OpenSSL.pm 
## Copyright (C) 2003-2005 Michael Bell

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Engine::OpenSSL;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine::OpenSSL

=head1 Description

The real implementation is in OpenXPKI::Crypto::Backend::OpenSSL::Engine.
This engine is only a dummy to allow interface compliant usage of
the reference implementation. OpenXPKI::Crypto::Backend::OpenSSL::Engine
includes a basic specification of every function and an
implmentation which bases on OpenSSL software keys.
