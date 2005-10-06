## OpenXPKI::DN
## Copyright (C) 2004-2005 Michael Bell
## $Revision$

use strict;
use warnings;
package OpenXPKI::DN;

sub new
{
    my $that  = shift;
    my $class = ref($that) || $that;
    my $self  = {};
    bless $self, $class;

    return undef if (not $_[0]);

    if (substr ($_[0],0, 1) eq "/")
    {
        ## proprietary OpenSSL oneline syntax
        my $dn = $_[0];
        $dn =~ s/^\///;
        my @dn = ();
        my $rdn = "";
        for (my $i = 0; $i < length ($dn); $i++)
        {
            if (substr ($dn, $i, 1) eq "\\")
            {
                $rdn .= substr ($dn, $i, 2);
                $i++;
                next;
            }
            if (substr ($dn, $i, 1) eq ",")
            {
                $rdn .= "\\,";
                next;
            }
            if (substr ($dn, $i, 1) eq "/")
            {
                push @dn, $rdn;
                $rdn = "";
                next;
            }
            $rdn .= substr ($dn, $i, 1);
        }
        $dn = join ", ", reverse @dn;
        $self->{PARSED} = [ get_parsed_rfc_2253 ($dn) ];
    } else {
        ## RFC2253 Syntax
        $self->{PARSED} = [ get_parsed_rfc_2253 ($_[0]) ];
    }
    $self->build_rdns();

    return $self;
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
    my @rdns = reverse @{$self->{RDNS}};
    for (my $i=0; $i < scalar @rdns; $i++)
    {
        $rdns[$i] =~ s/\//\\\//g;
    }
    return "/".join "/", @rdns;
}

sub get_hashed_content
{
    my $self = shift;
    my %result = ();

    for (my $i=0; $i < scalar @{$self->{PARSED}}; $i++)
    {
        ## RDN level
        for (my $k=0; $k < scalar @{$self->{PARSED}[$i]}; $k++)
        {
            ## attribute level
            push @{$result{uc $self->{PARSED}[$i][$k][0]}},
                 $self->{PARSED}[$i][$k][1];
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

sub build_rdns
{
    my $self = shift;
    $self->{RDNS} = [];
    $self->build_attributes() if (not $self->{ATTRIBUTES});

    for (my $i=0; $i < scalar @{$self->{ATTRIBUTES}}; $i++)
    {
        $self->{RDNS}[$i] = "";
        for (my $k=0; $k < scalar @{$self->{ATTRIBUTES}[$i]}; $k++)
        {
            $self->{RDNS}[$i] .= "+" if ($k>0);
            $self->{RDNS}[$i] .= $self->{ATTRIBUTES}[$i][$k];
        }
    }

    return 1;
}

sub build_attributes
{
    my $self = shift;
    $self->{ATTRIBUTES} = ();

    for (my $i=0; $i < scalar @{$self->{PARSED}}; $i++)
    {
        $self->{ATTRIBUTES}[$i] = ();
        for (my $k=0; $k < scalar @{$self->{PARSED}[$i]}; $k++)
        {
            my $value = $self->{PARSED}[$i][$k][1];
            $value =~ s/([+,])/\\$1/g;
            $self->{ATTRIBUTES}[$i][$k]  = $self->{PARSED}[$i][$k][0];
            $self->{ATTRIBUTES}[$i][$k] .= "=";
            $self->{ATTRIBUTES}[$i][$k] .= $value;
        }
    }

    return 1;
}

###########################################
##    END of structure initialization    ##
###########################################

##################################
##   BEGIN of RFC 2253 parser   ##
##################################

sub get_parsed_rfc_2253
{
    my $string = shift;
    while ($_[0])
    {
        $string = shift;
    }
    my @result = ();

    while ($string)
    {
        ($result[scalar @result], $string) = get_next_rdn ($string);
        $string = substr ($string, 1) if ($string); ## remove seperator
    }

    return @result;
}

sub get_next_rdn
{
    my $string = shift;
    my ($type, $value);
    my $result = [];

    while ($string)
    {
        ($type, $value, $string) = get_attribute ($string);
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

sub get_attribute
{
    my $string = shift;
    my ($type, $value);

    ($type, $string)  = get_attribute_type ($string);
    $string           = substr ($string, 1);
    ($value, $string) = get_attribute_value ($string);

    return ($type, $value, $string);
}

sub get_attribute_type
{
    my $string = shift;

    my $type = $string;
    $type    =~ s/^\s*//;
    $type    =~ s/^([^=]+)=.*/$1/;
    $string  =~ s/^\s*[^=]+(=.*)/$1/;

    ## fix type to be comliant with OpenSSL
    $type = "serialNumber" if (uc($type) eq "SERIALNUMBER");
    $type = "emailAddress" if (uc($type) eq "EMAILADDRESS");
    $type = "mail"         if (uc($type) eq "MAIL");
    $type = "UID"          if (uc($type) eq "UID");
    $type = "x500UniqueIdentifier" if (uc($type) eq "X500UNIQUEIDENTIFIER");
    $type = "CN"           if (uc($type) eq "CN");
    $type = "title"        if (uc($type) eq "TITLE");
    $type = "SN"           if (uc($type) eq "SN");
    $type = "OU"           if (uc($type) eq "OU");
    $type = "O"            if (uc($type) eq "O");
    $type = "L"            if (uc($type) eq "L");
    $type = "ST"           if (uc($type) eq "ST");
    $type = "C"            if (uc($type) eq "C");
    $type = "DC"           if (uc($type) eq "DC");
    $type = "pseudonym"    if (uc($type) eq "PSEUDONYM");
    $type = "role"         if (uc($type) eq "ROLE");
    $type = "description"  if (uc($type) eq "DESCRIPTION");

    return ($type, $string);
}

sub get_attribute_value
{
    my $string = shift;
    my $value  = "";
    my $length = length ($string);

    my $i = 0;
    my $next = substr ($string, $i, 1);
    while ($next !~ /[,+]/)
    {
        $i++ if ($next eq "\\");
        $value .= substr ($string, $i, 1);
        $i++;
        $next = substr ($string, $i, 1);
        last if ($length == $i);
    }

    $string = substr ($string, $i);

    return ($value, $string);
}

##################################
##    END of RFC 2253 parser    ##
##################################

1;
