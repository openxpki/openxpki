## OpenXPKI::Server::API::Object.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 431 $

package OpenXPKI::Server::API::Object;

use strict;
use warnings;
use utf8;
use English;

use Data::Dumper;

use Class::Std;

use OpenXPKI::Debug 'OpenXPKI::Server::API::Object';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::CSR;

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

sub get_csr_info_hash_from_data {
    ##! 1: "start"
    my $self  = shift;
    my $args  = shift;

    my $data  = $args->{DATA};
    my $realm = CTX('session')->get_pki_realm();
    my $token = CTX('pki_realm')->{$realm}->{crypto}->{default};
    my $obj   = OpenXPKI::Crypto::CSR->new (DATA => $data, TOKEN => $token);

    ##! 1: "finished"
    return $obj->get_info_hash();
}

sub get_ca_list
{
    ##! 1: "start"
    my $realm = CTX('session')->get_pki_realm();

    ##! 1: "finished"
    return CTX('pki_realm')->{$realm}->{ca}->{id};
}

sub get_ca_cert
{
    ##! 1: "start, forward and finish"
    my $self = shift;
    my $args = shift;
    return $self->get_cert($args);
}

sub get_cert
{
    ##! 1: "start"
    my $self = shift;
    my $args = shift;
    my @list = ();

    ##! 2: "initialize arguments"
    my $identifier = $args->{IDENTIFIER};

    ##! 2: "load hash and serialize it"
    my $hash = CTX('dbi_backend')->first (
                   TABLE => 'CERTIFICATE',
                   DYNAMIC => {
                       IDENTIFIER => $identifier,
                   },
                  );
    my $realm = CTX('session')->get_pki_realm();
    my $token = CTX('pki_realm')->{$realm}->{crypto}->{default};
    my $obj   = OpenXPKI::Crypto::X509->new(TOKEN => $token,
    		    			    DATA  => $hash->{DATA});

    ##! 1: "finished"
    return $obj->get_parsed_ref();
}

1;
__END__

=head1 Name

OpenXPKI::Server::API::Object

=head1 Description

This is the object interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=head2 get_csr_info_hash_from_data

return a hash reference which includes all parsed informations from
the CSR. The only accepted parameter is DATA which includes the plain CSR.

=head2 get_ca_list

returns a list of all available CAs in the used PKI realm.

=head2 get_ca_cert

returns the certificate of one CA. This is a wrapper around get_cert to make
the access control more fine granular if necessary.

=head2 get_cert

returns the requested certificate. the only supported argument is IDENTIFIER.
The return value is a serialized X509 object.
