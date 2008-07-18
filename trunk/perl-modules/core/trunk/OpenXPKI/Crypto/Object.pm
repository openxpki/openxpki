## OpenXPKI::Crypto::Object
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Object;

use OpenXPKI::Debug;
use OpenXPKI::Crypto::Header;
use OpenXPKI::Exception;
use English;

use Data::Dumper;

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
    ##! 16: Dumper $self

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

sub get_parsed_ref
{
    my $self  = shift;
    return $self->{PARSED};
}

sub get_serial {
    my $self = shift;
    return $self->get_parsed ("BODY", "SERIAL");
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

sub get_subject_alt_names {
    my $self = shift;

    my @subject_alt_names;
    eval { 
        @subject_alt_names = @{$self->get_parsed('BODY',
                                                 'OPENSSL_EXTENSIONS',
                                    'X509v3 Subject Alternative Name')};
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        # there are no subject alternative names in the object
        return;
    }
    else {
        ##! 64: 'subject_alt_names: ' . Dumper(\@subject_alt_names)
    
        my $all_sans = '';
        foreach my $san_line (@subject_alt_names) {
            $all_sans .= $san_line;
        }
        my @sans = split q{, }, $all_sans;
        foreach my $san (@sans) {
            ##! 64: 'san: ' . $san
            # convert from string to array ref of form [ 'DNS', 'example.com' ]
            my @temp = split /:/, $san;
            $san = [ $temp[0], $temp[1] ];
        }
        ##! 64: 'sans: ' . Dumper(\@sans)
        return @sans;
    }
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

=head2 get_parsed_ref

returns the parsed hash reference. Be warned - this function
should only be used to serialize and transport the hash. You
should never manipulate the data inside of the hash. Example:

$obj->get_parsed_ref ()

=head2 get_serial

returns the serial which is stored in the cryptographic body of
the object. Some objects like CSRs store the SERIAL in the HEADER.
Such types of objects must overwrite this function.

=head2 set_header_attribute

set an attribute in the header.

=head2 get_subject_alt_names

returns the subject alternative names in an array of arrays, i.e.
 [
    [ 'DNS', 'www.example.com' ],
    [ 'DNS', 'www.example.org' ],
]
This works only for certificates or certificate signing requests.
