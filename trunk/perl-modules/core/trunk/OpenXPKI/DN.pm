## OpenXPKI::DN
##
## Written by Michael Bell for the OpenXPKI project
## Copyright (C) 2004-2005 by The OpenXPKI Project

use strict;
use warnings;
use utf8;
package OpenXPKI::DN;

use Memoize;
use Text::CSV_XS;
use OpenXPKI::Exception;
use OpenXPKI::Debug;


# OpenSSL style attribute name mapping
my %mapping_of = (
    SERIALNUMBER         => "serialNumber",
    EMAILADDRESS         => "emailAddress",
    MAIL                 => "mail",
    UID                  => "UID",
    X500UNIQUEIDENTIFIER => "x500UniqueIdentifier",
    CN                   => "CN",
    TITLE                => "title",
    SN                   => "SN",
    OU                   => "OU",
    O                    => "O",
    L                    => "L",
    ST                   => "ST",
    C                    => "C",
    DC                   => "DC",
    DOMAINCOMPONENT      => "DC",
    PSEUDONYM            => "pseudonym",
    ROLE                 => "role",
    DESCRIPTION          => "description",
    );

sub new
{
    my $that  = shift;
    my $class = ref($that) || $that;
    my $self  = {};
    bless $self, $class;

    my $arg = shift;

    return undef if (! defined $arg && ($arg eq ""));

    ##! 2: "scanning dn: $arg"
    ##! 2: "length of dn: ".length $arg

    if (substr ($arg, 0, 1) eq "/")
    {
        ## proprietary OpenSSL oneline syntax
        my $dn = convert_openssl_dn($arg);
        $self->{PARSED} = [ $self->__get_parsed_rfc_2253 ($dn) ];
    } else {
        ## RFC2253 Syntax
        $self->{PARSED} = [ $self->__get_parsed_rfc_2253 ($arg) ];
    }
    $self->__build_rdns();

    return $self;
}

# convert OpenSSL DN to RFC2253 DN
sub convert_openssl_dn
{
    ##! 1: 'warning: OpenSSL DN used. Can not be parsed unambigously! This may even lead to security issues. Avoid whenever possible!'
    my $dn = shift;

    my $openssl_format
 	= Text::CSV_XS->new({
 	    sep_char    => q{/},    # Fields are separated by /
 	    escape_char => q{\\},   # Backslashed characters are always data
	});
    
    if (!$openssl_format->parse($dn)) {
 	OpenXPKI::Exception->throw (
 	    message => "I18N_OPENXPKI_DN_CONVERT_OPENSSL_DN_PARSE_ERROR",
 	    params  => {
 		DN          => $dn,
 		BADARGUMENT => $openssl_format->error_input(),
 	    });
    }
    
    my @rdn = $openssl_format->fields();

    # remove first empty element (OpenSSL DN starts with /)
    shift @rdn;

    # return comma separated list, escape commas include in rdns
    # RFC 4514 says RDNS are joined by q{,} not q{, }
    return join(",", reverse map { s{,}{\\,}xsg; $_; } @rdn);
}

###################################
##   BEGIN of output functions   ##
###################################

sub get_parsed
{
    my $self = shift;
    return @{$self->{PARSED}};
}

sub get_attributes
{
    my $self = shift;
    return @{$self->{ATTRIBUTES}};
}

sub get_rdns
{
    my $self = shift;
    return @{$self->{RDNS}};
}

sub get_rfc_2253_dn
{
    my $self = shift;
    return join ",", @{$self->{RDNS}};
}

sub get_x500_dn
{
    my $self = shift;
    return join ",", reverse @{$self->{RDNS}};
}

sub get_openssl_dn
{
    my $self = shift;

    # the map operation below modifies its arguments, so make a copy first
    my @rdns = @{$self->{RDNS}};

    # escape / to \/ and return /-separated DN
    return "/" . join("/", 
		      reverse map { s{/}{\\/}xsg; $_; } @rdns);
}

sub get_hashed_content
{
    my $self = shift;
    my %result = ();

    for my $rdn (@{$self->{PARSED}}) {
	for my $attribute (@{$rdn}) {
	    my $key = uc($attribute->[0]);

	    push @{$result{$key}}, $attribute->[1];
	}
    }

    return %result;
}

###################################
##    END of output functions    ##
###################################

###########################################
##   BEGIN of structure initialization   ##
###########################################

sub __build_rdns
{
    my $self = shift;
    $self->{RDNS} = [];
    $self->__build_attributes() if (not $self->{ATTRIBUTES});

    for my $attribute (@{$self->{ATTRIBUTES}}) {
	push(@{$self->{RDNS}}, join("+", @{$attribute}));
    }

    return 1;
}

sub __build_attributes
{
    my $self = shift;
    $self->{ATTRIBUTES} = ();

    for my $entry (@{$self->{PARSED}}) {
	my @attributes = ();
	
 	for my $item (@{$entry}) {
 	    my $key   = $item->[0];
 	    my $value = $item->[1];

	    # escape + and , 
	    $value =~ s{ ([+,]) }{\\$1}xs;
 	    push(@attributes, $key . '=' . $value);
 	}
	
 	push(@{$self->{ATTRIBUTES}}, \@attributes);
     }

    return 1;
}

###########################################
##    END of structure initialization    ##
###########################################

##################################
##   BEGIN of RFC 2253 parser   ##
##################################

sub __get_parsed_rfc_2253
{
    my $self   = shift;
    my $string = shift;

    my @result = ();

    while ($string)
    {
	my $rdn;
        ($rdn, $string) = $self->__get_next_rdn ($string);
	if (defined $rdn && $rdn ne "") {
	    push(@result, $rdn);
	}

        $string = substr ($string, 1) if ($string); ## remove seperator
    }

    return @result;
}

sub __get_next_rdn
{
    my $self   = shift;
    my $string = shift;
    my ($type, $value);
    my $result = [];

    while ($string)
    {
        ($type, $value, $string) = $self->__get_attribute ($string);
        $result->[scalar @{$result}] = [ $type, $value ];
        last if (substr ($string, 0, 1) eq ","); ## stop at ,
        if (length ($string) > 1)
        {
            $string = substr ($string, 1);           ## remove +
        } else {
            $string = "";
        }
    }

    return ($result, $string);
}

sub __get_attribute
{
    my $self   = shift;
    my $string = shift;
    my ($type, $value);

    ($type, $string)  = __get_attribute_type ($string);
    $string           = substr ($string, 1);
    ($value, $string) = __get_attribute_value ($string);
    ##! 2: "type:  $type\nvalue: $value"

    return ($type, $value, $string);
}

sub __get_attribute_type
{
    my $string = shift;

    my $type = $string;
    $type    =~ s/^\s*//;
    $type    =~ s/^([^=]+)=.*/$1/;
    $string  =~ s/^\s*[^=]+(=.*)/$1/;

    ## fix type to be comliant with OpenSSL
    if (exists $mapping_of{uc($type)}) {
	$type = $mapping_of{uc($type)};
    }

    return ($type, $string);
}

sub __get_attribute_value
{
    my $string = shift;
    my $value  = "";
    my $length = length ($string);

    my $i = 0;
    my $next = substr ($string, $i, 1);
    while ($length > $i and $next !~ /[,+]/)
    {
        $i++ if ($next eq "\\");
        $value .= substr ($string, $i, 1);
        $i++;
        $next = substr ($string, $i, 1);
    }

    $string = substr ($string, $i);

    return ($value, $string);
}

sub get_attribute_names
{
    my @values = sort values %mapping_of;
    for (my $i=scalar @values -1; $i > 0; $i--)
    {
        splice @values, $i, 1 if ($values[$i] eq $values[$i-1]);
    }
    return @values;
}

##################################
##    END of RFC 2253 parser    ##
##################################

foreach my $function (qw (__get_parsed_rfc_2253
                          __get_next_rdn
                          __get_attribute
                          __get_attribute_type
                          __get_attribute_value
                          ) ) {
    memoize($function);
}

		      
1;
__END__

=head1 Name

OpenXPKI::DN - RFC 2253 compatible dn parsing with support for OpenSSL's
proprietary formatting rules.

=head1 Description

This module was designed to implement a fast parser for RFC 2253
distinguished names. It was designed to output RFC 2253 compliant
and OpenSSL formatted DNs. Additionally you can get the parsed
RDNs and the attributes in a hash (e.g. if you are looking for
the organizational hierarchy via OUs).

Please note that OpenSSL formatted DNs can not be parsed unambigously.
This is because '/' is a perfectly valid character within an RDN but
is used to separate them as well. Avoid getting OpenSSL DNs from
OpenSSL or other applications whenever possible, as this parsing
problem might lead to security issues.

=head1 Initialization

=head2 new

The 'new' constructor expects a RFC 2253 or OpenSSL DN as its only
argument. The type of the DN will be detected from the first
character. OpenSSL's DNs always begin with a leading slash "/".

The return value is an object reference to the used instance of
OpenXPKI::DN.

=head2 convert_openssl_dn

This is a static function which requires an OpenSSL DN as
argument. It returns a proper RFC 2253 DN. It is used by the 'new'
constructor to convert OpenSSL DNs but you can use it also if you 
don't need a full parser (which is slower).

=head1 Output Functions

=head2 get_parsed

returns a three-dimensional array. The first level is the number
of the RDN, the second level is the number of the attribute and
third level contains at [0] the name of the attribute and at [1]
the value of the attribute.

=head2 get_attributes

returns a two-dimensional array. The first level is the number
of the RDN, the second level is the number of the attribute.
The value is the attribute name and value concatenated with an
equal sign "=".

=head2 get_rdns

returns an array. The array values are completely prepared
strings of the RDNs. This works for multi-valued RDNs too.

=head2 get_rfc_2253_dn

returns the RFC 2253 DN.

=head2 get_x500_dn

returns the RFC 2253 DN in reversed order. Something like X.500
style.

=head2 get_openssl_dn

returns the DN in OpenSSL's proprietary oneline format.

=head2 get_hashed_content

returns a hash which contains the attribute names as keys. The
value of each hashentry is an array with the values inside which
were found in the DN.

=head2 get_attribute_names

is a static function which returns all supported attribute names
as a normal array. It is not relevant how you call this function.
