## OpenXPKI::Server::Session::Mock.pm 
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

package OpenXPKI::Server::Session::Mock;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use Data::Dumper;

my %pki_realm : ATTR( :get<pki_realm> :set<pki_realm> );
# the following three are relevant for SCEP only
my %profile   : ATTR( :get<profile>   :set<profile>   );
my %server    : ATTR( :get<server>    :set<server>    );
my %enc_alg   : ATTR( :get<enc_alg>   :set<enc_alg>   );

my %id        : ATTR( :get<id>   :default<-1> );
my %user      : ATTR( :get<user> :default<''> :set<user> );
my %role      : ATTR( :get<role> :set<role> :default<''> );
my %challenge : ATTR( :get<challenge> :set<challenge> );
my %authentication_stack : ATTR( :get<authentication_stack> :set<authentication_stack> );
my %language  : ATTR( :get<language> :set<language> );
my %secret    : ATTR( :get<secret> :set<secret> );
my %state    : ATTR( :get<state> :set<state> );


sub START {
    my $self    = shift;
    my $ident   = shift;
    my $arg_ref = shift;
    
    my $session_obj = $arg_ref->{SESSION};
    ##! 16: 'session obj: ' . Dumper $session_obj
    # clone if SESSION is passed
    if (defined $session_obj) {
        $self->set_pki_realm($session_obj->get_pki_realm());
        $id{$ident} = $session_obj->get_id();
        $user{$ident} = $session_obj->get_user();
        $self->set_role($session_obj->get_role());
        $self->set_authentication_stack($session_obj->get_authentication_stack());
        $self->set_language($session_obj->get_language());
        $self->set_secret($session_obj->get_secret());
        $self->set_state($session_obj->get_state());
    }
}

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
  
