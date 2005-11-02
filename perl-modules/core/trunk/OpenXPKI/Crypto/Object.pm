## OpenXPKI::Crypto::Object
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::Object;

use OpenXPKI qw(debug);
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

sub get_item
{
    my $self = shift;
    return $self->{header}->get_item();
}

sub get_parsed
{
    my $self  = shift;
    my $ref   = $self->{PARSED};

    foreach my $name (@_)
    {
        $ref = $ref->{$name};
    }
    if (ref($ref))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OBJECT_GET_PARSED_NO_VALUE");
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
    $self->debug ("entering function");
    $self->{header}->set_attribute (@_);
    $self->{DATA} = $self->{header}->get_item();

    ## if you call init then all information is lost !!!
    $self->debug ("reiniting object");
    eval
    {
        $self->__init();
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OBJECT_SET_HEADER_ATTRIBUTE_REINIT_FAILED",
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }
    return 1;
}

1;
__END__

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

=head2 get_item

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
