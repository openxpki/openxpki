## OpenXPKI::Crypto::Object
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Object;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Object';
use OpenXPKI::Crypto::Header;
use OpenXPKI::Exception;
use English;

sub get_header
{
    my $self = shift;
    return $self->{header}->get_header();
}

sub get_body
{
    my $self = shift;
    return $self->{header}->get_body();
}

sub get_raw
{
    my $self = shift;
    return $self->{header}->get_raw();
}

sub get_parsed
{
    my $self  = shift;
    my $ref   = $self->{PARSED};

    foreach my $name (@_)
    {
        if (defined $ref and exists $ref->{$name})
        {
            $ref = $ref->{$name};
        } else {
            $ref = undef;
        }
    }
    if (not defined $ref or ref($ref) eq "HASH")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OBJECT_GET_PARSED_NO_VALUE",
            params  => {"NAME" => join ("/", @_)});
    } else {
        return $ref;
    }
}

sub get_serial {
    my $self = shift;
    return $self->get_parsed ("BODY", "SERIAL");
}

sub get_status
{
    my $self = shift;
    if (not exists $self->{STATUS})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OBJECT_GET_STATUS_NOT_INITIALIZED");
    }
    return $self->{STATUS};
}

sub set_status
{
    my $self = shift;
    $self->{STATUS} = shift;
    return $self->get_status();
}

sub set_header_attribute
{
    my $self = shift;
    ##! 1: "start"
    $self->{header}->set_attribute (@_);
    $self->{DATA} = $self->{header}->get_raw();

    ## if you call init then all information is lost !!!
    ##! 2: "reiniting object"
    eval
    {
        $self->__init();
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_CRYPTO_OBJECT_SET_HEADER_ATTRIBUTE_REINIT_FAILED",
            children => [ $exc ]);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Object

=head1 Description

This class is a basic implementation for all cryptographic objects
which are supported by OpenXPKI. It includes several basic function
which are common for all crypto objects. The most common functions
base on the OpenXPKI::Crypto::Header class which is used by OpenXPKI
to store non-standard and dynamic information of objects.

=head1 Functions

=head2 get_header

returns the plain header of the object.

=head2 get_body

returns the plain (cryptographic) body of the object.

=head2 get_raw

returns the complete plain object.

=head2 get_parsed

expects an array which is a path to parsed value. Example:

$obj->get_parsed ("HEADER", "SERIAL")

=head2 get_serial

returns the serial which is stored in the cryptographic body of
the object. Some objects like CSRs store the SERIAL in the HEADER.
Such types of objects must overwrite this function.

=head2 get_status

returns the status of the object.

=head2 set_status

sets the status of the object.

=head2 set_header_attribute

set an attribute in the header.
