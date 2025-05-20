package OpenXPKI::Crypto::Tool::CreateJavaKeystore::Engine::OpenSSL;
use OpenXPKI;

use parent qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);

1;

=head1 Name

OpenXPKI::Crypto::Tool::CreateJavaKeystore:Engine::OpenSSL

=head1 Description

The real implementation is in OpenXPKI::Crypto::Backend::OpenSSL::Engine.
This engine is only a dummy to allow interface compliant usage of
the reference implementation. OpenXPKI::Crypto::Backend::OpenSSL::Engine
includes a basic specification of every function and an
implmentation which bases on OpenSSL software keys.
