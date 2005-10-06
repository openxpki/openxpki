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
