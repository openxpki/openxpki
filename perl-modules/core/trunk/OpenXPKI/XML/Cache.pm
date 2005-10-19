## OpenXPKI::XML::Cache
## Copyright (C) 2003-2005 Michael Bell
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::XML::Cache;

use XML::Simple;
use XML::Parser;
$XML::Simple::PREFERRED_PARSER = "XML::Parser";
use OpenXPKI qw(debug);
use OpenXPKI::Exception;

#######################################
##          General functions        ##
#######################################

sub new
{ 
    my $that  = shift;
    my $class = ref($that) || $that;
  
    my $self = {};
   
    bless $self, $class;

    my $keys = { @_ };

    $self->{DEBUG}  = $keys->{DEBUG};
    $self->{config} = $keys->{CONFIG};

    return undef if (not $self->init ());

    $self->debug("dump: ".$self->dump());

    return $self;
}

sub init
{
    my $self = shift;
    $self->debug ("start");
    my $xs   = XML::Simple->new (ForceArray    => 1,
                                 ForceContent  => 1,
                                 SuppressEmpty => undef,
                                 KeepRoot      => 1);

    delete $self->{cache} if (exists $self->{cache});
    foreach my $input (@{$self->{config}})
    {
	# if input contains '<>' characters, we are passed a raw XML string
	# otherwise we assume a filename
	my $filename = "[Literal XML string]";
	if ($input !~ m{[<>]}) {
	    $filename = $input;
	}
	$self->debug ("filename: $filename");

        my $xml = eval { $xs->XMLin ($input); };
        if (not $xml and $@)
        {
            my $msg = $@;
            delete $self->{cache} if (exists $self->{cache});
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_INIT_XML_ERROR",
                params  => {"FILE"   => $filename,
                            "ERRVAL" => $msg});
        }
        if (not exists $self->{cache})
        {
            $self->debug ("cache is empty");
            $self->{cache} = $xml->{openxpki}->[0];
            next;
        }

        foreach my $key (sort keys %{$xml->{openxpki}->[0]})
        {
            $self->debug ("handling section $key");
            if (not exists $self->{cache}->{$key})
            {
                $self->debug ("there is no such section until now");
                $self->{cache}->{$key} = $xml->{openxpki}->[0]->{$key};
                next;
            }
            $self->debug ("extending section");
            foreach my $name (keys %{$xml->{openxpki}->[0]->{$key}->[0]})
            {
                $self->debug ("adding $name to $key");
                $self->{cache}->{$key}->[0]->{$name} = $xml->{openxpki}->[0]->{$key}->[0]->{$name};
            }
        }
    }
    return 1;
}

sub dump
{
    my $self  = shift;
    my $msg   = "";
    my $ref   = $self->{cache};
    $ref = shift if ($_[0]);

    foreach my $key (keys %{$ref})
    {
        $msg .= "name --> $key\n";
        if (not ref ($ref->{$key}))
        {
            $msg .= "value --> ".$ref->{$key}."\n";
        } else {
            foreach my $item (@{$ref->{$key}})
            {
                next if (not defined $item); ## happens on empty arrays
                if (ref ($item))
                {
                    $msg .= "  ".join ("\n  ", split "\n", $self->dump ($item))."\n";
                } else {
                    $msg .= "valueunref --> $item\n";
                }
            }
        }
    }
    return $msg;
}

sub get_xpath
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_XPATH",
        errno   => 400)
        if (not $keys->{XPATH});

    if (ref ($keys->{XPATH}) eq "ARRAY")
    {
        if (ref ($keys->{COUNTER}) ne "ARRAY")
        {
            $keys->{COUNTER} = [ $keys->{COUNTER} ];
        }
        $keys->{COUNTER} = [ @{$keys->{COUNTER}}, "0" ]
            if (scalar @{$keys->{XPATH}} > scalar @{$keys->{COUNTER}});
    } else {
        $keys->{COUNTER} = 0 if (not $keys->{COUNTER});
        $keys->{XPATH}   = [ $keys->{XPATH} ];
        $keys->{COUNTER} = [ $keys->{COUNTER} ];
    }

    $keys = $self->__get_params (XPATH   => $keys->{XPATH},
                                 COUNTER => $keys->{COUNTER});

    my $item = $self->{cache};
    for (my $i=0; $i<scalar @{$keys->{XPATH}}; $i++)
    {
        if (not exists $item->{$keys->{XPATH}->[$i]} or
            not exists $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]])
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_ELEMENT",
                params  => {"XPATH" =>    $self->__get_serialized_xpath($keys),
                            "TAG"   =>    $keys->{XPATH}->[$i],
                            "POSITION" => $keys->{COUNTER}->[$i]});
        }
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
    }
    if (not exists $item->{content})
    {
        ## the tag is present but does not contain anything
        ## this is no error !
        return "";
    }
    ## WARNING: you need a utf8 capable terminal to see the correct characters
    ## $self->debug ("content: ".$item->{content});
    #unpack/pack is too slow, try to use "use utf8;"
    #$self->debug ("content: ".pack ("U0C*", unpack "C*", $item->{content}));
    #return pack "U0C*", unpack "C*", $item->{content};
    $self->debug ("content: ".$item->{content});
    return $item->{content};
}

sub get_xpath_list
{
    my $self = shift;
    $self->debug ("start");

    my $ref = $self->get_xpath_count (REF => 1, @_);
    return undef if (not defined $ref);
    return []    if (not ref $ref); ## happens when there are no results

    my @list = ();
    foreach my $item (@{$ref})
    {
        if (not exists $item->{content})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_CONTENT",
                params  => {"XPATH" => $self->__get_serialized_xpath({@_})});
        }
        # unpack/pack is too slow, try to use "use utf8;"
        #push @list, pack "U0C*", unpack "C*", $item->{content};
        push @list, $item->{content};
    }
    return \@list;
}

sub get_xpath_count
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_COUNT_MISSING_XPATH",
        errno   => 400)
        if (not $keys->{XPATH});

    if (ref ($keys->{XPATH}) eq "ARRAY")
    {
        if (exists $keys->{COUNTER} and
            defined $keys->{COUNTER} and
            ref ($keys->{COUNTER}) ne "ARRAY")
        {
            $keys->{COUNTER} = [ $keys->{COUNTER} ];
        }
    } else {
        if (not $keys->{COUNTER})
        {
            $keys->{COUNTER} = undef;
        } else {
            $keys->{COUNTER} = [ $keys->{COUNTER} ];
        }
        $keys->{XPATH}   = [ $keys->{XPATH} ];
    }

    $keys = $self->__get_params (%{$keys});

    my $item = $self->{cache};
    for (my $i=0; $i<scalar @{$keys->{COUNTER}}; $i++)
    {
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
        if (not $item)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_COUNT_MISSING_ELEMENT",
                params  => {"XPATH"    => $self->__get_serialized_xpath($keys),
                            "TAG"      => $keys->{XPATH}->[$i],
                            "POSITION" => $keys->{COUNTER}->[$i]});
        }
    }
    $self->debug ("scan complete");
    return 0 if (not exists $item->{$keys->{XPATH}->[scalar @{$keys->{COUNTER}}]});
    $self->debug ("at minimum one exists");
    $item = $item->{$keys->{XPATH}->[scalar @{$keys->{COUNTER}}]};
    ## this is a hack (internal feature) for get_xpath_list
    return $item if ($keys->{REF});
    $self->debug ("content: ".scalar @{$item});
    return scalar @{$item};
}

sub __get_params
{
    my $self = shift;
    my $keys = { @_ };

    my $params = undef;
    $params->{XPATH}   = [];
    $params->{COUNTER} = [];

    for (my $i=0; $i<scalar @{$keys->{XPATH}}; $i++)
    {
        $self->debug ("scan: ".$keys->{XPATH}->[$i]);
        my @names = split /\//, $keys->{XPATH}->[$i];
        foreach my $name (@names)
        {
            $self->debug ("part: $name");
            $params->{XPATH}   = [ @{$params->{XPATH}},   $name ];
            $params->{COUNTER} = [ @{$params->{COUNTER}}, 0 ];
        }
        if (not exists $keys->{COUNTER} or
            not $keys->{COUNTER} or
            $i == scalar @{$keys->{COUNTER}})
        {
            $self->debug ("removed counter");
            delete $params->{COUNTER}->[scalar @{$params->{COUNTER}} -1];
        } else {
            $self->debug ("replaced counter");
            $params->{COUNTER}->[scalar @{$params->{COUNTER}} -1] = $keys->{COUNTER}->[$i];
        }
    }
    ## preserve other parameters
    $keys->{XPATH}   = $params->{XPATH};
    $keys->{COUNTER} = $params->{COUNTER};
    if ($self->{DEBUG})
    {
        $self->debug ("xpath: ".join ", ", @{$keys->{XPATH}});
        $self->debug ("counter: ".join ", ", @{$keys->{COUNTER}});
    }
    return $keys;
}

sub __get_serialized_xpath
{
    my $self    = shift;
    my $keys    = shift;
    my $xpath   = $keys->{XPATH};
    my $counter = $keys->{COUNTER};
    my $result = "";

    for (my $i=0; $i < scalar @{$xpath}; $i++)
    {
        $result .= "/" if (length($result));
        $result .= $xpath->[$i];
        $result .= "/".$counter->[$i] if (defined $counter->[$i]);
    }
    return $result;
}

1;
__END__

=head1 Description

=head1 XML::Parser and XML::Simple

We enforce the usage of XML::Parser by XML::Simple because some other
parsers does not create an error if the XML document is malformed.
These parsers tolerate errors!

=head1 Functions

=head2 new

create the class instance and calls internally the function init to
load the XML files for the first time. The supported parameters are
DEBUG and CONFIG. DEBUG can be a true or false value. CONFIG is an
array reference which contains either filenames including the configuration
or strings containing the XML configuration literally. Filenames
and literal XML strings can be mixed. A parameter is considered a literal
XML string if it contains a '<' or '>' character.

=head2 init

This function loads all XML files (or literal XML strings) and initializes 
the internal data structures. After init you have a constant access 
performance.

=head2 dump

returns a human readable dump of the XML cache data.

=head2 get_xpath

This function returns the value of the submitted XML path. So
please do not expect that xpath has something todo with the XML
standard XPATH.

There are two available options COUNTER and XPATH. Both can be
single scalars or array references. First you have to understand
the interpretation by an example.

$cache->get_xpath (XPATH   => ["abc/def", "xyz"],
                   COUNTER => [2, 3]);

This means that you search the third tag (2+1) with the name
"def" in the tag "abc". The returned value will be the value of
the fourth (3+1) value of tag "xyz" in the defined tag "def". You
can also write this as follows:

$cache->get_xpath (XPATH   => ["abc", "def", "xyz"],
                   COUNTER => [0, 2, 3]);

If a path is definite then you can remove the zero and concatenate
the tag names with slashes "/".

You can use the following calling conventions:

$cache->get_xpath (XPATH   => ["abc", "def", "xyz"],
                   COUNTER => [0, 2, 3]);

$cache->get_xpath (XPATH   => ["abc/def", "xyz"],
                   COUNTER => [2, 3]);

$cache->get_xpath (XPATH   => ["abc/def"],
                   COUNTER => [0]);

$cache->get_xpath (XPATH   => "abc/def",
                   COUNTER => 0);

$cache->get_xpath (XPATH   => "abc/def");

It is strongly recommend to only use the three following use cases.
All other use cases can be deprectaed in the future. The last variant
will usually not used because the second is more readable.

$cache->get_xpath (XPATH   => "abc/def");

$cache->get_xpath (XPATH   => ["abc/def", "xyz"],
                   COUNTER => [2, 3]);

$cache->get_xpath (XPATH   => ["abc", "def", "xyz"],
                   COUNTER => [0, 2, 3]);

=head2 get_xpath_count

The interface is exacatly the same like for get_xpath with one big
exception. COUNTER is always one element shorter than XPATH. The
result is the number of available values with the specified path.

=head2 get_xpath_list

The interface is the same like for get_xpath_count. Only the return
value is different. It returns an array reference to the found
values.
