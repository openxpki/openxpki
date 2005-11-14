## OpenXPKI::XML::Cache
##
## Written by Michael Bell for the OpenXPKI project
## Copyright (C) 2003-2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::XML::Cache;

## this is for the caching itself
use XML::Simple;
use XML::Parser;
$XML::Simple::PREFERRED_PARSER = "XML::Parser";

## this is for the XML schema validation only
use XML::SAX::Writer;
use XML::Validator::Schema;
use XML::Filter::XInclude;
use XML::SAX::ParserFactory;
$XML::SAX::ParserPackage = "XML::SAX::PurePerl";

use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use English;

#######################################
##          General functions        ##
#######################################

sub new
{ 
    my $that  = shift;
    my $class = ref($that) || $that;
  
    my $self = {DEBUG => 0};
   
    bless $self, $class;

    my $keys = { @_ };

    $self->{DEBUG}  = $keys->{DEBUG}  if ($keys->{DEBUG});
    $self->{config} = $keys->{CONFIG};
    $self->{schema} = $keys->{SCHEMA} if (exists $keys->{SCHEMA});

    return undef if (not $self->init ());

#    use Data::Dumper;
#    print STDERR Dumper($self->{cache});
#    $self->debug("dump: ".$self->dump());

    return $self;
}

sub init
{
    my $self = shift;
    $self->debug ("start");

    ## validate the XML file

    if (exists $self->{schema})
    {
        my $writer    = XML::SAX::Writer->new();
        my $validator = XML::Validator::Schema->new (Handler => $writer,
                                                     file    => $self->{schema});
        my $xinclude  = XML::Filter::XInclude->new  (Handler => $validator);
        $self->{parser} = XML::SAX::ParserFactory->parser(
                              Handler => $xinclude);
        if ($self->{config} !~ m{[<>]}) {
            eval { $self->{parser}->parse_uri ($self->{config}) };
        } else {
            eval { $self->{parser}->parse_string ($self->{config}) };
        }
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_INIT_XML_SCHEMA_ERROR",
                params  => {"ERRVAL" => $EVAL_ERROR });
        }
    }

    ## load the data

    $self->debug ("load the XML data");
    $self->{xs} = XML::Simple->new (ForceArray    => 1,
                                    ForceContent  => 1,
                                    SuppressEmpty => undef,
                                    KeyAttr       => [],
                                    KeepRoot      => 1);

    delete $self->{cache} if (exists $self->{cache});

    # if input contains '<>' characters, we are passed a raw XML string
    # otherwise we assume a filename
    my $filename = "[Literal XML string]";
    if ($self->{config} !~ m{[<>]}) {
        $filename = $self->{config};
    }
    $self->debug ("filename: $filename");

    my $xml = eval { $self->{xs}->XMLin ($self->{config}); };
    if (not $xml and $@)
    {
        my $msg = $@;
        delete $self->{cache} if (exists $self->{cache});
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_XML_CACHE_INIT_XML_ERROR",
            params  => {"FILE"   => $filename,
                        "ERRVAL" => $msg});
    }
    $self->{cache} = $xml->{openxpki}->[0];
    $self->{xtree}->{$filename}->{LEVEL} = 1;
    $self->{xtree}->{$filename}->{REF}   = $self->{cache};

    $self->__perform_xinclude();

    return 1;
}

sub __perform_xinclude
{
    my $self = shift;
    $self->debug ("start");

    ## scan configuration for unresolved xincludes

    my @xincludes = $self->__scan_xinclude ($self->{cache});
    return 1 if (not scalar @xincludes);
    $self->debug ("xinclude tag detected");

    ## include the XML stuff

    foreach my $xinclude (@xincludes)
    {
        ## find insert position for the new XML data
        $self->debug ("integrate loaded XML data into XML tree");
        my $ref = $self->{cache};
        my $path = $self->{config};
        my $elements = scalar @{$xinclude->{XPATH}} - 1;
        for (my $i=0; $i < $elements; $i++)
        {
            my $xpath = $xinclude->{XPATH}->[$i];
            my $count = $xinclude->{COUNTER}->[$i];
            if (exists $self->{xref}->{$ref} and
                exists $self->{xref}->{$ref}->{$xpath} and
                exists $self->{xref}->{$ref}->{$xpath}->{$count})
            {
                $path = $self->{xref}->{$ref}->{$xpath}->{$count};
            }
            $ref = $ref->{$xpath};
            $ref = $ref->[$count];
        }

        ## calculate the correct filename
        $self->debug ("calculate filename from path $path");
        my $filename = $xinclude->{XPATH}->[$elements];
        if ($filename !~ /^\//)
        {
            $path =~ s%/[^/]*$%/%;
            $filename = $path.$filename;
        }

        ## loop detection
        ## protection against endless loops
        $self->debug ("check for loop");
        if (exists $self->{xtree} and
            exists $self->{xtree}->{$filename})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_PERFORM_XINCLUDE_LOOP_DETECTED",
                params  => {"FILENAME"   => $filename});
        }


        ## load the xinclude file
        $self->debug ("load the included file $filename");
        my $xml = eval { $self->{xs}->XMLin ($filename) };
        if (not $xml and $@)
        {
            my $msg = $@;
            delete $self->{cache} if (exists $self->{cache});
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_PERFORM_XINCLUDE_XML_ERROR",
                params  => {"FILE"   => $filename,
                            "ERRVAL" => $msg});
        }
        my $top = join "", keys %{$xml};
        $self->debug ("top element of $filename is $top");

        ## insert the data into the XML structure
        if (exists $ref->{$top})
        {
            $ref->{$top} = [ @{$ref->{$top}}, $xml->{$top}->[0] ];
        } else {
            $ref->{$top} = $xml->{$top};
        }

        ## store position of file in XML tree
        $self->debug ("store reference for the filename");
        $self->{xref}->{$ref}->{$top}->{scalar @{$ref->{$top}} -1} = $filename;
        $self->{xtree}->{$filename}->{REF}   = $ref;
        $self->{xtree}->{$filename}->{NAME}  = $top;
        $self->{xtree}->{$filename}->{POS}   = scalar @{$ref->{$top}} -1;
        $self->{xtree}->{$filename}->{LEVEL} = 0;
    }

    ## update the levels

    $self->debug ("update tree level of the different files");
    foreach my $file (keys %{$self->{xtree}})
    {
        $self->{xtree}->{$file}->{LEVEL}++;
    }

    ## resolve the new xincludes

    $self->debug ("start next round of xinclude detection");
    return $self->__perform_xinclude();
}

## this function returns an array
## every array element is a hash
## every hash includes two arrays - the path elements and number of the element
## Example: my @ret = ({XPATH   => ["token", "/etc/token.xml],
##                      COUNTER => ["1", "0"]});
sub __scan_xinclude
{
    my $self = shift;
    my $ref  = shift;
    my @result = ();
    $self->debug ("start");

    ## scan hash for xi tags

    foreach my $key (keys %{$ref})
    {
        if ($key ne "xi:include")
        {
            next if (ref $ref->{$key} ne "ARRAY"); ## content
            $self->debug ("scanning tag $key");
            ## is a reference to other elements
            for (my $i=0; $i < scalar @{$ref->{$key}}; $i++)
            {
                my @ret = $self->__scan_xinclude ($ref->{$key}->[$i]);
                for (my $k=0; $k < scalar @ret; $k++)
                {
                    $ret[$k]->{XPATH}   = [$key, @{$ret[$k]->{XPATH}}];
                    $ret[$k]->{COUNTER} = [$i, @{$ret[$k]->{COUNTER}}];
                }
                push @result, @ret;
            }
        }
        else
        {
            $self->debug ("xi:include tag present");
            for (my $i=0; $i < scalar @{$ref->{"xi:include"}}; $i++)
            {
                ## namespace must be correct
                if ($ref->{"xi:include"}->[$i]->{"xmlns:xi"} !~ /XInclude/i)
                {
                }
                $self->debug ("xi:include tag correct");
                ## extracting data
                push @result, {XPATH   => [ $ref->{"xi:include"}->[$i]->{"href"} ],
                               COUNTER => [ $i ]};
                $self->debug ("file ".$ref->{"xi:include"}->[$i]->{"href"}." ready for include");
            }
            ## delete xinclude tags to avoid loops
            delete $ref->{"xi:include"};
        }
    }
    $self->debug ("end");
    return @result;
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

    my $item = $self->{cache};
    for (my $i=0; $i<scalar @{$keys->{XPATH}}; $i++)
    {
#        print STDERR "XPATH: ".$keys->{XPATH}->[$i]."\n";
#        print STDERR "COUNTER: ".$keys->{COUNTER}->[$i]."\n";
#        print STDERR "length ok\n" if ($i+1 == scalar @{$keys->{XPATH}});
#        print STDERR "exists ok\n" if (exists $item->{$keys->{XPATH}->[$i]});
#        print STDERR "no ref ok\n" if (not ref $item->{$keys->{XPATH}->[$i]});
#        print STDERR "counter ok\n" if ($keys->{COUNTER}->[$i] == 0);
        if (not exists $item->{$keys->{XPATH}->[$i]} or
            not ref $item->{$keys->{XPATH}->[$i]} or
            not exists $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]])
        {
            if ($i+1 == scalar @{$keys->{XPATH}} and
                exists $item->{$keys->{XPATH}->[$i]} and
                not ref $item->{$keys->{XPATH}->[$i]} and
                $keys->{COUNTER}->[$i] == 0)
            {
                ## this is an attribute request
                $self->debug ("attribute request: ".$item->{$keys->{XPATH}->[$i]});
                return $item->{$keys->{XPATH}->[$i]};
            }
            else
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_ELEMENT",
                    params  => {"XPATH" =>    $self->__get_serialized_xpath($keys),
                                "TAG"   =>    $keys->{XPATH}->[$i],
                                "POSITION" => $keys->{COUNTER}->[$i]});
            }
        }
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
    }
    if (not exists $item->{content})
    {
        ## the tag is present but does not contain anything
        ## this is no error !
        $self->debug ("no content");
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

    my $item = $self->{cache};
    for (my $i=0; $i<scalar @{$keys->{COUNTER}}; $i++)
    {
#        print STDERR "XPATH: ".$keys->{XPATH}->[$i]."\n";
#        print STDERR "COUNTER: ".$keys->{COUNTER}->[$i]."\n";
        if (not exists $item->{$keys->{XPATH}->[$i]} or
            not ref $item->{$keys->{XPATH}->[$i]} or
            not exists $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]])
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_COUNT_MISSING_ELEMENT",
                params  => {"XPATH"    => $self->__get_serialized_xpath($keys),
                            "TAG"      => $keys->{XPATH}->[$i],
                            "POSITION" => $keys->{COUNTER}->[$i]});
        }
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
    }
    $self->debug ("scan complete");
    if (not exists $item->{$keys->{XPATH}->[scalar @{$keys->{COUNTER}}]})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_COUNT_NOTHING_FOUND");
    }
    $self->debug ("at minimum one exists");
    $item = $item->{$keys->{XPATH}->[scalar @{$keys->{COUNTER}}]};
    ## this is a hack (internal feature) for get_xpath_list
    return $item if ($keys->{REF});
    $self->debug ("content: ".scalar @{$item});
    return scalar @{$item};
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
DEBUG, CONFIG and SCHEMA.

=over

=item * DEBUG

can be a true or false value. Default is false.

=item * CONFIG

is a string which contains either a filename including the configuration
or a string containing the XML configuration literally.  A parameter is
considered a literal XML string if it contains a '<' or '>' character.
The parameter is required.

=item * SCHEMA

specifies the filename of the XML schema definition. If this
parameter is present then the loaded XML file will be checked to
be valid in the meaning of the schema. The parameter is optional.

=back

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

There are two available options COUNTER and XPATH. Both must be
arrays. The example shows the usage.

$cache->get_xpath (XPATH   => ["abc", "def", "xyz"],
                   COUNTER => [0, 2, 3]);

=head2 get_xpath_count

The interface is exactly the same like for get_xpath with one big
exception. COUNTER is always one element shorter than XPATH. The
result is the number of available values with the specified path.

=head2 get_xpath_list

The interface is the same like for get_xpath_count. Only the return
value is different. It returns an array reference to the found
values.
