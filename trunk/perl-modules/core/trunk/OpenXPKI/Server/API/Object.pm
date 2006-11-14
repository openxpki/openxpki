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
use OpenXPKI::FileUtils;

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

    ##! 2: "initialize arguments"
    my $identifier = $args->{IDENTIFIER};
    my $format     = "HASH";
       $format     = $args->{FORMAT} if (exists $args->{FORMAT});

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

    ##! 2: "return if a HASH reference was requested"
    return $obj->get_parsed_ref() if ($format eq "HASH");

    ##! 1: "finished"
    return $obj->get_converted($format);
}

sub get_crl
{
    ##! 1: "start"
    my $self = shift;
    my $args = shift;

    ##! 2: "initialize arguments"
    my $ca_id    = $args->{CA_ID};
    my $filename = $args->{FILENAME};
    my $format   = "PEM";
       $format   = $args->{FORMAT} if (exists $args->{FORMAT});

    ##! 2: "checks the parameters for correctness"
    my $realm = CTX('session')->get_pki_realm();
    if (not exists CTX('pki_realm')->{$realm})
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_MISSING_PKI_REALM_CONFIG',
        );
    }
    if (not exists CTX('pki_realm')->{$realm}->{ca}->{id}->{$ca_id})
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_MISSING_CA_CONFIG',
        );
    }
    if (not CTX('pki_realm')->{$realm}->{ca}->{id}->{$ca_id}->{crl_publication})
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_PUBLIC',
        );
    }

    ##! 2: "check the specified file"
    my $files   = CTX('pki_realm')->{$realm}->{ca}->{id}->{$ca_id}->{crl_files};
    my $correct = 0;
    foreach my $fileset (@{$files})
    {
        next if ($fileset->{FILENAME} ne $filename);
        next if ($fileset->{FORMAT}   ne $format);
        $correct = 1;
        last;
    }
    if (not $correct)
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_FOUND',
        );
    }

    ##! 2: "load the file and return it (finished)"
    my $fu = OpenXPKI::FileUtils->new();
    return $fu->read_file($filename);
}

sub search_cert
{
    ##! 1: "start"
    my $self = shift;
    my $args = shift;
    my @list = ();

    ##! 2: "fix arguments"
    $args->{EMAIL}   =~ s/\*/%/g;
    $args->{SUBJECT} =~ s/\*/%/g;
    $args->{ISSUER}  =~ s/\*/%/g;

    ##! 2: "initialize arguments"
    my %params = (TABLE => 'CERTIFICATE');
       $params{SERIAL}       = $args->{CERT_SERIAL} if ($args->{CERT_SERIAL});
       $params{LIMIT}        = $args->{LIMIT}       if ($args->{LIMIT});
       $params{TO}           = $args->{LAST}        if ($args->{LAST});
       $params{REVERSE}      = 1                    if ($args->{LAST});
       $params{FROM}         = $args->{FIRST}       if ($args->{FIRST});
       $params{DYNAMIC}->{IDENTIFIER} = $args->{IDENTIFIER} if ($args->{IDENTIFIER});
       $params{DYNAMIC}->{CSR_SERIAL} = $args->{CSR_SERIAL} if ($args->{CSR_SERIAL});
       $params{DYNAMIC}->{EMAIL}      = $args->{EMAIL}      if ($args->{EMAIL});
       $params{DYNAMIC}->{SUBJECT}    = $args->{SUBJECT}    if ($args->{SUBJECT});
       $params{DYNAMIC}->{ISSUER}     = $args->{ISSUER}     if ($args->{ISSUER});

    ##! 2: "load hashes and serialize them"
    my $result = CTX('dbi_backend')->select (%params);
    foreach my $item (@{$result})
    {
        ## delete data to minimize transport costs
        delete $item->{DATA};
        push @list, \%{$item};
    }
    @list = reverse @list if ($args->{LAST});

    ##! 1: "finished"
    return \@list;
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

returns the requested certificate. The supported arguments are IDENTIFIER and
FORMAT. IDENTIFIER is required whilst FORMAT is optional. FORMAT can have the
following values:

=over

=item * PEM

=item * DER

=item * PKCS7 - without the usual hash mark

=item * TXT

=item * HASH - the default value

=back

=head2 search_cert

supports a facility to search certificates. It supports the following parameters:

=over

=item * CERT_SERIAL

=item * LIMIT

=item * LAST

=item * FIRST

=item * CSR_SERIAL

=item * EMAIL

=item * SUBJECT

=item * ISSUER

=back

The result is an array of hashes. The hashes do not contain the data field
of the database to reduce the transport costs an avoid parser implementations
on the client.

=head2 get_crl

returns a CRL. The required parameters are CA_ID, FILENAME and FORMAT. CA_ID is
the configured ID of the CA in the PKI realm configuration. FILENAME and FORMAT
are from the configuration too and must match a configured CRL. Both parameters
will be checked against the configuration. So there it is not possible to attack
the system with this filename because we validate it.
