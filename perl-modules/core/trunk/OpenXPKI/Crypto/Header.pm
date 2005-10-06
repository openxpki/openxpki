## OpenXPKI::Crypto::Header
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;

package OpenXPKI::Crypto::Header;

use OpenXPKI qw (debug i18nGettext set_error errno errval);

our ($errno, $errval);

our $beginHeader    = "-----BEGIN HEADER-----";
our $endHeader      = "-----END HEADER-----";
our $beginAttribute = "-----BEGIN ATTRIBUTE-----";
our $endAttribute   = "-----END ATTRIBUTE-----";

($OpenXPKI::Crypto::Header::VERSION = '$Revision: 1.3 $' )=~ s/(?:^.*: (\d+))|(?:\s+\$$)/defined $1?"0\.9":""/eg;

=head1 DESCRIPTION

This module is a parser for all OpenXPKI objects. It parses the complete
object before the normal modules take over.

=head1 Public functions

=head2 new

The parameters are DEBUG and DATA. The result is an object reference to
the parsed data.

=cut

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };

    $self->{DEBUG} = $keys->{DEBUG};
    $self->{data}  = $keys->{DATA};

    $self->__parse();
    $self->__init();

    return $self;
}

=head2 get_header

return the prepared header with begin and end lines.

=cut

sub get_header
{
    my $self = shift;
    return $self->{header};
}

=head2 get_body

returns the pure body of the object

=cut

sub get_body
{
    my $self = shift;
    return $self->{body};
}

=head2 get_item

returns the complete plain object

=cut

sub get_item
{
    my $self = shift;
    return $self->{item};
}

=head2 get_parsed

returns the parsed header values. This is a deep copy.
So you can manipulate it

=cut


sub get_parsed
{
    my $self = shift;
    return \%{$self->{head}};
}

=head2 set_attribute

sets a new header attribute which was not in the original data

=cut

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

=head2 get_attribute

returns a header attribute

=cut

sub get_attribute
{
    my $self = shift;
    my $attr = shift;
    return $self->{head}->{uc($attr)};
}

=head1 Internal functions

=head2 __parse

parses the data from new

=cut

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

=head2 __init

initializes the internal variables for the public getter functions.

=cut

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
