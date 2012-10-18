## OpenXPKI::Crypto::Tool::CreateJavaKeystore
## Written 2006 by Alexander Klink for the OpenXPKI project
## based on OpenXPKI::Crypto::Toolkit
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::CreateJavaKeystore;
use base qw( OpenXPKI::Crypto::Toolkit );	

use strict;
use warnings;

use Class::Std;

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::CreateJavaKeystore - create_javakeystore wrapper

=head1 Description

This class provides an interface to CreateKeystore, a Java program to
create Java keystores which may include private keys

=head1 See Also

OpenXPKI::Crypto::Toolkit
