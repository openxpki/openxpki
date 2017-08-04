## OpenXPKI::Server::Workflow::NICE::Null.pm
## NICE Backend for Realms without any issuance of certificates
## (e. g. CA only realms where CA certificates and CRLs are imported from outside)
##
## Written 2016 by Martin Bartosch <m.bartosch@cynops.de>
## for the OpenXPKI project
## (C) Copyright 2016 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::NICE::Null;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Moose;
#use namespace::autoclean; # Conflicts with Debugger


extends 'OpenXPKI::Server::Workflow::NICE';


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::NICE::Null

=head1 Description

This module implements a dummy OpenXPKI NICE Interface for Realms which do not issue
certificates themselves but which are used to manage external information, e. g. a
"CA Only" Realm which manages externally issued CA certificates or CRLs.

This may be useful for situations in which the certificate and CRL publishing mechanisms
of OpenXPKI shall be used.

=head1 Configuration

The module does not require nor accept any configuration options.

Any call to issuance of certificates or CRLs will trigger an exception.
