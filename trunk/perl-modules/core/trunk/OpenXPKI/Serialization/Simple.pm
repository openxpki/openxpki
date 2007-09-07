# OpenXPKI::Serialization::Simple.pm
# Written 2006 by Michael Bell for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;
use utf8;

package OpenXPKI::Serialization::Simple;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Encode;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        "SEPARATOR" => "\n",
    };

    bless $self, $class;

    my $keys = shift;
    if ( exists $keys->{SEPARATOR} ) {
        $self->{SEPARATOR} = $keys->{SEPARATOR};
    }

    if ( length($self->{SEPARATOR}) != 1 ) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_SEPARATOR_TOO_LONG",
            params  => {
                SEPARATOR => $self->{SEPARATOR}
            }
        );
    }
    if ( $self->{SEPARATOR} =~ /^[0-9]$/ ) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_SEPARATOR_IS_NUMERIC",
            params  => {
                SEPARATOR => $self->{SEPARATOR}
            }
        );
    }

    return $self;
}





sub serialize {
    my $self = shift;
    my $data = shift;

    return $self->__write_data($data);
}

sub __write_data {
    my $self = shift;
    my $data = shift;
    my $msg  = "";

    if ( ref $data eq "" && defined $data ) {
        # it's a scalar
        return $self->__write_scalar($data);
    }
    elsif ( ref $data eq "ARRAY" && defined $data ) {
        # it's an array
        return $self->__write_array($data);
    }
    elsif ( ref $data eq "HASH" && defined $data ) {
        # it's a hash
        return $self->__write_hash($data);
    }
    elsif ( not defined $data ) {
        # it's an undef
        return $self->__write_undef();
    }
    elsif ( "$data" ne '' ) {
        # it's not something of the above, but seems to have a valid
        # stringification
        # TODO - do we want this to rather throw an exception and clean
        # up the code that calls the serialization not to use any objects?
        ##! 1: 'implicit stringification of ' . ref $data . ' object'
        return $self->__write_scalar("$data");
    }
    else {
        # data type is not supported
        OpenXPKI::Exception->throw ( 
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_WRITE_DATA_TYPE_NOT_SUPPORTED",
            params  => {
                DATA      => $data,
                DATA_TYPE => ref $data,
            }
        );
    }

    return $msg;
}

sub __write_scalar {
    my $self = shift;
    my $data = shift;

    my $separator = $self->{SEPARATOR};
 
    # downgrade unicode characters to bytes
    $data = pack("C*", unpack("U0C*", $data));

    return "SCALAR".$separator.
           length($data).$separator.
           $data.$separator;
}

sub __write_array {
    my $self = shift;
    my $data = shift;
    my $msg  = "";

    my $separator = $self->{SEPARATOR};

    for (my $i = 0; $i<scalar @{$data}; $i++) {
        $msg .= $i.$separator.
                $self->__write_data($data->[$i]);
    }

    return "ARRAY".$separator.
           length($msg).$separator.
           $msg;
}

sub __write_hash {
    my $self = shift;
    my $data = shift;
    my $msg  = "";

    my $separator = $self->{SEPARATOR};

    foreach my $key ( sort keys %{$data} ) {
        $msg .= length ($key).$separator.
                $key.$separator.
                $self->__write_data($data->{$key});
    }

    return "HASH".$separator.
           length ($msg).$separator.
           $msg;
}


sub __write_undef {
    my $self = shift;

    my $separator = $self->{SEPARATOR};

    return "UNDEF".$separator;
}






sub deserialize {
    my $self = shift;
    my $msg  = shift;
    Encode::_utf8_off($msg);

    my $ret = $self->__read_data($msg);

    return $ret->{data};
}

sub __read_data {
    my $self = shift;
    my $msg  = shift;

    my $separator = $self->{SEPARATOR};

    if ( $msg =~ /^SCALAR$separator/ ) { 
        # it's a scalar
        return $self->__read_scalar($msg);
    }
    elsif ( $msg =~ /^ARRAY$separator/ ) { 
        # it's an array
        return $self->__read_array($msg);
    }
    elsif ( $msg =~ /^HASH$separator/ ) {
        # it's a hash
        return $self->__read_hash($msg);
    }
    elsif ( $msg =~ /^UNDEF$separator/ ) {
        # it's an undef
        return $self->__read_undef($msg);
    }
    else {
        # data type is not supported
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_DATA_TYPE_NOT_SUPPORTED",
            params  => {
                MSG => $msg
            }
        );
    }

    return $msg;
}

sub __read_scalar {
    my $self   = shift;
    my $msg    = shift;

    my $separator = $self->{SEPARATOR};

    my $returnmessage = "";

    # check for correct scalar format
    if ( not $msg =~ /^SCALAR$separator[0-9]+$separator/ ) {
        # scalar is not formatted appropriately
        OpenXPKI::Exception->throw (
             message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_SCALAR_FORMAT_CORRUPTED",
             params  => {
                 MSG => $msg
             }
        ); 
    }
        
    # extract scalar length
    $msg =~ /^SCALAR$separator([0-9]+)$separator/;
    my $scalarlength = $1;

    # extract scalar value
    if ( ( length($msg) - length($scalarlength) - 8 ) < $scalarlength ) {
        # remaining msg is shorter than what would be interpreted as scalar value
        OpenXPKI::Exception->throw ( 
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_SCALAR_DENOTED_LENGTH_TOO_LONG",
            params  => {
                MSG => $msg,
                DENOTED_SCALAR_LENGTH => $scalarlength,
                REMAINING_MSG_LENGTH  => length($msg)
            }
        );
    } 
    my $scalarvalue = substr ($msg, length($scalarlength) + 8, $scalarlength);

    # create return message used to extract scalar data
    $returnmessage = "SCALAR$separator$scalarlength$separator$scalarvalue$separator";

    # convert bytes to unicode characters
    $scalarvalue = pack("U0C*", unpack("C*", $scalarvalue));

    return {
        data          => $scalarvalue,
        returnmessage => $returnmessage
    };
}

sub __read_array {
    my $self  = shift;
    my $msg   = shift;

    my @array = ();

    my $separator = $self->{SEPARATOR};

    my $returnmessage = "";

    # read length of array
    if ( not $msg =~ /^ARRAY$separator[0-9]+$separator/ ) {
        # array (length of array, respectively) is not formatted appropriately
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_LENGTH_FORMAT_CORRUPTED",
            params  => {
                MSG => $msg
            }
        );
    }
    $msg =~ /^ARRAY$separator([0-9]+)$separator/;
    my $arraylength = $1;

    # create return message used to extract array
    $msg =~ /^(ARRAY$separator[0-9]+$separator)/; 
    $returnmessage = $1;

    # isolate upcoming array elements in msg
    $msg = substr ($msg, length($returnmessage));

    # iterate through array elements
    while ( $arraylength > 0 ) {
        # read array element position
        if ( not $msg =~ /^[0-9]+$separator/ ) {
            # array (array element position, respectively) is not formatted appropriately
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_ELEMENT_POSITION_FORMAT_CORRUPTED",
                params  => {
                    MSG => $msg
                }
            );
        }
        $msg =~ /^([0-9]+)$separator/;
        my $arrayelementposition = $1;

        # add array alement position to return message
        $msg =~ /^([0-9]+$separator)/;
        $returnmessage .= $1;

        # cut off array element position from msg
        $msg = substr ($msg, length($arrayelementposition)+1);

        # used for consistency check at the end of the while loop
        $arraylength -= (length($arrayelementposition)+1);

        # read data
        my $data = $self->__read_data ($msg);

        # process data (write data into array)
        push (@array, $data->{data});

        # complete return message
        $returnmessage .= $data->{returnmessage};

        # cut off the part of msg that has already been processed
        $msg = substr ($msg, length($data->{returnmessage}));

        # used for consistency check at the end of the while loop
        $arraylength -= (length($data->{returnmessage}));
    }

    # consistency check
    if ( $arraylength != 0 ) {
         # array length corrupted (this should ALWAYS be zero after successful processing)
         OpenXPKI::Exception->throw (
             message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_ARRAY_LENGTH_CORRUPTED",
             params  => {
                 REMAINING_ARRAY_LENGTH          => $arraylength,
                 EXPECTED_REMAINING_ARRAY_LENGTH => 0
             } 
         );
    }

    return {
        data           => \@array,
        returnmessage  => $returnmessage
    };
}

sub __read_hash {
    my $self = shift;
    my $msg  = shift;

    my %hash = ();

    my $separator = $self->{SEPARATOR};

    my $returnmessage = "";

    # read total length of hash
    if ( not $msg =~ /^HASH$separator[0-9]+$separator/ ) {
        # hash (hash length, respectively) is not formatted appropriately
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_LENGTH_FORMAT_CORRUPTED",
            params  => {
                MSG => $msg
            }
        );
    }        
    $msg =~ /^HASH$separator([0-9]+)$separator/;
    my $hashlength = $1;

    # create return message used to extract hash
    $msg =~ /^(HASH$separator[0-9]+$separator)/;
    $returnmessage = $1;    
   
    # isolate upcoming hash elements in msg
    $msg = substr ($msg, length($returnmessage));

    # iterate through hash elements
    while ( $hashlength > 0 ) {
        # read length of hash key
        if ( not $msg =~ /^[0-9]+$separator/ ) {
            # hash (hash length, respectively) is not formatted appropriately
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_KEY_LENGTH_FORMAT_CORRUPTED", 
                params  => { 
                    MSG => $msg
                }
            );
        }
        $msg =~ /^([0-9]+)$separator/;
        my $hashkeylength = $1;

        # complete return message
        $returnmessage .= "$hashkeylength$separator";

        # cut off hash key length from msg
        $msg = substr ($msg, length($hashkeylength)+1);

        # used for consistency check at the end of the while loop
        $hashlength -= (length($hashkeylength)+1);

        # read hash key
        $msg =~ /^([^$separator]+)$separator/;
        my $hashkey = $1;

        # complete return message
        $returnmessage .= "$hashkey$separator";

        # cut off hash key from msg
        $msg = substr ($msg, length($hashkey)+1);

        # used for consistency check at the end of the while loop
        $hashlength -= (length($hashkey)+1);

        # check for correct hash key length
        if( length($hashkey) != $hashkeylength ) {
            # actual length of hash key differs from denoted length
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_KEY_LENGTH_CORRUPTED",
                params  => {
                    ACTUAL_LENGTH  => length($hashkey),
                    DENOTED_LENGTH => $hashkeylength,
                    SCALAR_VALUE   => $hashkey,
		    MSG            => $msg
                }
            );
        }

        # read data 
        my $data = $self->__read_data ($msg);

        # process data (write data into hash)
        $hash{$hashkey} = $data->{data};

        # complete return message
        $returnmessage .= $data->{returnmessage};

        # cut off the part of msg that has already been processed
        $msg = substr ($msg, length($data->{returnmessage}));

        # used for consistency check at the end of the while loop
        $hashlength -= (length($data->{returnmessage}));
    }

    # consistency check
    if ( $hashlength != 0 ) {
        # hash length corrupted (this should ALWAYS be zero after successful processing)
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_HASH_LENGTH_CORRUPTED",
            params  => {
                REMAINING_HASH_LENGTH          => $hashlength,
                EXPECTED_REMAINING_HASH_LENGTH => 0
            }
        );
    }

    return {
        data           => \%hash,
        returnmessage  => $returnmessage
    };
}

sub __read_undef {
    my $self   = shift;
    my $msg    = shift;

    my $separator = $self->{SEPARATOR};

    my $returnmessage = "";

    if ( not $msg =~ /^UNDEF$separator/ ) {
        # undef is not formatted appropriately
        OpenXPKI::Exception->throw (  
            message => "I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_UNDEF_FORMAT_CORRUPTED", 
            params  => { 
                MSG => $msg
            }
        );
    }

    $msg =~ /^(UNDEF$separator)/;
    $returnmessage = $1;

    return {
        data           => undef,
        returnmessage  => $returnmessage
    };
}





1;
__END__

=head1 Name

OpenXPKI::Serialization::Simple

=head1 Description

Really simple serialization class for scalars, arrays and hashes.
This is a platform neutral example implementation. It mainly
demonstrates the interface and can easily be ported to other
scripting languages.

=head1 Functions

=head2 new

Initializes the object.

=head2 serialize

Returns the serialization of data passed as argument.

=head2 deserialize

Returns the deserialization of data passed as argument.

=head1 Internal Functions

=head2 Serialization

=head3 __write_data

This function returns the serialization of data passed as argument by 
calling one or more of the following functions. Each of those functions 
serializes a specific data type according to the syntax (see below). An 
exception is thrown if the data type cannot be recognized.

=head3 __write_scalar

=head3 __write_array

=head3 __write_hash

=head3 __write_undef

=head2 Deserialization

=head3 __read_data

This function returns the deserialization of data passed as argument by 
calling one or more of the following functions. Each of those functions 
deserializes a specific data type according to the syntax (see below). An 
exception is thrown if the data type cannot be recognized.

Basically, the deserialization works as follows: While scalars and undefs 
are easily deserialized upon recognition, it's a bit more tricky with arrays 
and hashes. Since they can possibly contain more (complex) data, each of the 
functions below returns two values: "$data" holds the deserialized data, and 
"$returnmessage" returns the (serialized) string that was used to deserialize 
the data. The latter value is important to keep track of which part of the 
serialized string has already been deserialized.

=head3 __read_scalar

=head3 __read_array

=head3 __read_hash

=head3 __read_undef

=head1 Syntax

We support scalars, array references and hash references 
in any combination. The syntax is the following one:

scalar        ::= 'SCALAR'.SEPARATOR.
                  [0-9]+.SEPARATOR. /* length of data */
                  data.SEPARATOR

array         ::= 'ARRAY'.SEPARATOR.
                  [0-9]+.SEPARATOR. /* length of array data */
                  array_element+

array_element ::= [0-9]+.SEPARATOR. /* position in the array */
                  (hash|array|scalar)

hash          ::= 'HASH'.SEPARATOR.
                  [0-9]+.SEPARATOR. /* length of hash data */
                  hash_element+

hash_element  ::= [1-9][0-9]*.SEPARATOR.    /* length of the hash key */
                  [a-zA-Z0-9_]+.SEPARATOR.  /* the hash key */
                  (hash|array|undef|scalar)

undef         ::= 'UNDEF'.SEPARATOR.

The SEPARATOR is one character long. It can be any non number.
The default separator is newline. The important thing is
that you can parse every structure without knowing the used
SEPARATOR.

Perhaps the good mathmatics notice that the last SEPARATOR
in the definition of a scalar is not necessary. This SEPARATOR
is only used to make the resulting structure better readable
for humans.
