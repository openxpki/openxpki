## OpenXPKI::Crypto::OpenSSL::Engine::OpenSSL.pm 
## Copyright (C) 2003-2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Engine::OpenSSL;

use OpenXPKI::Crypto::OpenSSL::Engine;
use vars qw(@ISA);
@ISA = qw(OpenXPKI::Crypto::OpenSSL::Engine);

our ($errno, $errval);

1;
