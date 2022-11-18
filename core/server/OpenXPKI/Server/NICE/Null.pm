package OpenXPKI::Server::NICE::Null;

use Moose;
extends 'OpenXPKI::Server::NICE';

__PACKAGE__->meta->make_immutable;

__END__

=head1 Name

OpenXPKI::Server::NICE::Null

=head1 Description

This module implements a dummy OpenXPKI NICE Interface for Realms which do not issue
certificates themselves but which are used to manage external information, e. g. a
"CA Only" Realm which manages externally issued CA certificates or CRLs.

This may be useful for situations in which the certificate and CRL publishing mechanisms
of OpenXPKI shall be used.

=head1 Configuration

The module does not require nor accept any configuration options.

Any call to issuance of certificates or CRLs will trigger an exception.
