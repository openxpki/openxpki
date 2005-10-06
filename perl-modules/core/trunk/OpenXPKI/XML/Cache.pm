## OpenXPKI::XML::Cache
##
## Copyright (C) 2003-2005 Michael Bell

use strict;
use warnings;

package OpenXPKI::XML::Cache;

=head1 XML::Parser and XML::Simple

We enforce the usage of XML::Parser by XML::Simple because some other
parsers does not create an error if the XML document is malformed.
These parsers tolerate errors!

=cut

use XML::Simple;
use XML::Parser;
$XML::Simple::PREFERRED_PARSER = "XML::Parser";
use OpenXPKI qw(debug set_error errno errval);

## the other use directions depends from the used databases
## $Revision: 0.1.1.2 

($OpenXPKI::XML::Cache::VERSION = '$Revision: 1.21 $' )=~ s/(?:^.*: (\d+))|(?:\s+\$$)/defined $1?"0\.9":""/eg; 

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

    return undef if (not $self->init (@_));

    $self->debug("dump: ".$self->dump());

    return $self;
}

sub init
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");
    my $xs   = XML::Simple->new (ForceArray    => 1,
                                 ForceContent  => 1,
                                 SuppressEmpty => undef,
                                 KeepRoot      => 1);

    delete $self->{cache} if (exists $self->{cache});
    foreach my $filename (@{$self->{config}})
    {
        $self->debug ("filename: $filename");
        my $xml = eval { $xs->XMLin ($filename); };
        if (not $xml and $@)
        {
            my $msg = $@;
            delete $self->{cache} if (exists $self->{cache});
            $self->set_error ("I18N_OPENXPKI_XML_CACHE_INIT_XML_ERROR",
                              "__FILE__", $filename,
                              "__ERRVAL__", $msg);
            return undef;
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
        $msg .= "$key\n";
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

    return $self->set_error (400, "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_XPATH")
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
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
        if (not $item)
        {
            $self->set_error ("I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_ELEMENT",
                              "__XPATH__", $self->__get_serialized_xpath($keys),
                              "__TAG__", $keys->{XPATH}->[$i],
                              "__POSITION__", $keys->{COUNTER}->[$i]);
            return undef;
        }
    }
    if (not exists $item->{content})
    {
        ## the tag is present but does not contain anything
        ## this is no error !
        return "";
    }
    ## WARNING: you need a utf8 capable terminal to see the correct characters
    ## $self->debug ("content: ".$item->{content});
    $self->debug ("content: ".pack ("U0C*", unpack "C*", $item->{content}));
    return pack "U0C*", unpack "C*", $item->{content};
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
            $self->set_error ("I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_CONTENT",
                              "__XPATH__", $self->__get_serialized_xpath({@_}));
            return undef;
        }
        push @list, pack "U0C*", unpack "C*", $item->{content};
    }
    return \@list;
}

sub get_xpath_count
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    return $self->set_error (400, "I18N_OPENXPKI_XML_CACHE_GET_XPATH_COUNT_MISSING_XPATH")
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
            $self->set_error ("I18N_OPENXPKI_XML_CACHE_GET_XPATH_COUNT_MISSING_ELEMENT",
                              "__XPATH__", $self->__get_serialized_xpath($keys),
                              "__TAG__", $keys->{XPATH}->[$i],
                              "__POSITION__", $keys->{COUNTER}->[$i]);
            return undef;
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
