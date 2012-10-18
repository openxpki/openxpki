## OpenXPKI::Crypto::Header
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;

package OpenXPKI::Crypto::Header;

our $beginHeader    = "-----BEGIN HEADER-----";
our $endHeader      = "-----END HEADER-----";
our $beginAttribute = "-----BEGIN ATTRIBUTE-----";
our $endAttribute   = "-----END ATTRIBUTE-----";

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };

    $self->{data}  = $keys->{DATA};

    $self->__parse();
    $self->__init();

    return $self;
}

sub get_header
{
    my $self = shift;
    return $self->{header};
}

sub get_body
{
    my $self = shift;
    return $self->{body};
}

sub get_raw
{
    my $self = shift;
    return $self->{item};
}

sub get_parsed
{
    my $self = shift;
    return \%{$self->{head}};
}

sub set_attribute
{
    my $self = shift;
    my $keys = { @_ };

    foreach my $attr (keys %{$keys}) {
        $self->{head}->{uc($attr)} = $keys->{$attr};
        $self->{head}->{uc($attr)} =~ s/[\r\n]*$//s;
    }
    $self->__init();
    return 1;
}

sub get_attribute
{
    my $self = shift;
    my $attr = shift;
    return $self->{head}->{uc($attr)};
}

sub __parse
{
    my $self = shift;

    ## get plain header
    $self->{header} = $self->{data};
    $self->{header} =~ s/^.*$beginHeader\s*\r?\n([\s\S\r\n]+)\n$endHeader.*/$1/s;
    $self->{header} = "" if (index ($self->{data}, $beginHeader) < 0);

    ## get plain body

    $self->{body} = $self->{data};
    $self->{body} =~ s/^.*\n$endHeader[\r\n]*(.*)$/$1/s;
    $self->{body} =~ s/[\r\n]*$//s;

    ## parse header

    my $active_multirow = 0;
    my ($key, $val) = ("", "");
    foreach my $i ( split ( /\s*\r?\n/, $self->{header} ) ) {
        if ($active_multirow) {
            ## multirow
            if ($i =~ /^$endAttribute$/) {
                ## end of multirow
                $active_multirow = 0;
            } else {
                $self->{head}->{$key} .= "\n" if ($self->{head}->{$key});
                ## additional data
                $self->{head}->{$key} .= $i;
            }
        } elsif ($i =~ /^$beginAttribute$/) {
            ## begin of multirow
            $active_multirow = 1;
        } else {
            ## no multirow 
            ## if multirow then $ret->{key} is initially empty)
            ## fix CR
            $i =~ s/\s*\r$//;
            $i =~ s/\s*=\s*/=/;
            ( $key, $val ) = ( $i =~ /^([^=]*)\s*=\s*(.*)\s*/ );
            $key = uc($key);
            $self->{head}->{$key} = $val;
            ## fix old requests
            $self->{head}->{SUBJECT} = $val if ($key eq "SUBJ");
        }
    }

    return 1;
}

sub __init
{
    my $self = shift;

    ## build new header
    $self->{header} = $beginHeader."\n";
    foreach my $key (sort keys %{$self->{head}})
    {
        if (index ($self->{head}->{$key}, "\n") > -1)
        {
            $self->{header} .= uc($key)."=\n".
                               "${beginAttribute}\n".
                               $self->{head}->{$key}."\n".
                               "${endAttribute}\n";
        } else {
            $self->{header} .= uc($key)."=".$self->{head}->{$key}."\n";
        }
    }
    $self->{header} .= $endHeader;
    $self->{header} =~ s/\r\n/\n/g;
    $self->{header} =~ s/\n/\r\n/g;

    ## fix body
    $self->{body} =~ s/\r\n/\n/g;
    $self->{body} =~ s/\n/\r\n/g;

    ## build item
    ## do not attach \r\n this is removed by browser from input fields
    $self->{item} = $self->{header}."\r\n".
                    $self->{body};

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Header

=head1 Description

This module is a parser for all OpenXPKI objects. It parses the complete
object before the normal modules take over.

=head1 Functions

=head2 new

The only parameter is DATA. The result is an object reference to
the parsed data.

=head2 get_header

return the prepared header with begin and end lines.

=head2 get_body

returns the pure body of the object

=head2 get_raw

returns the complete plain object

=head2 get_parsed

returns the parsed header values. This is a deep copy.
So you can manipulate it

=head2 set_attribute

sets a new header attribute which was not in the original data

=head2 get_attribute

returns a header attribute

