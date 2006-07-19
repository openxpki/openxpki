## OpenXPKI::Server::Session::Mock.pm 
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 400 $

package OpenXPKI::Server::Session::Mock;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use OpenXPKI::Debug 'OpenXPKI::Server::Session::Mock';
use OpenXPKI::Exception;

my %pki_realm : ATTR( :get<pki_realm> :set<pki_realm> );


1;
__END__

=head1 Name

OpenXPKI::Server::Session::Mock

=head1 Description

This class mimics the behaviour of the default session class but actually
does nothing stateful. In particular it does not save the session
information.

However, during the lifetime of the object instance it is possible to
stow information into the session object and to retrieve them again
using the accessor methods.

This is useful e. g. for Service implementations that do not need sessions
themselves but that rely on API functions which access the server context
in order to extract session information such like the current PKI realm.

Typical usage:

  use OpenXPKI::Server::Context qw( CTX );
  use OpenXPKI::Server::Session::Mock;

  my $session = OpenXPKI::Server::Session::Mock->new();
  OpenXPKI::Server::Context::setcontext({'session' => $session});

  CTX('session')->set_pki_realm('foobar');

You can now use API functions that require e. g. the PKI realm information
to be present in the Context.
  
