## OpenXPKI::Crypto::Tool::CreateJavaKeystore::Engine::OpenSSL.pm 
## Written 2006 by Alexander Klink for the OpenXPKI project
## Copyright (C) 2006 by the OpenXPKI Project
# TODO: create dummy engine instead of using Backend engine

use strict;
use warnings;

package OpenXPKI::Crypto::Tool::CreateJavaKeystore::Engine::OpenSSL;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::CreateJavaKeystore:Engine::OpenSSL

=head1 Description

The real implementation is in OpenXPKI::Crypto::Backend::OpenSSL::Engine.
This engine is only a dummy to allow interface compliant usage of
the reference implementation. OpenXPKI::Crypto::Backend::OpenSSL::Engine
includes a basic specification of every function and an
implmentation which bases on OpenSSL software keys.
