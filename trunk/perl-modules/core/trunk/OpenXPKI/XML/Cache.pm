# OpenXPKI::XML::Cache
##
## Written by Michael Bell for the OpenXPKI project
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## Enhanced to do super tag substition at initialization 2007 by
## Alexander Klink for the OpenXPKI project
## (C) Copyright 2003-2007 by The OpenXPKI Project

package OpenXPKI::XML::Cache;

use strict;
use warnings;
use utf8;

use English;
use File::Spec;

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

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Fast;

use Data::Dumper;

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

    $self->{config}           = $keys->{CONFIG};
    $self->{schema}           = $keys->{SCHEMA} if (exists $keys->{SCHEMA});
    $self->{serialized_cache} = $keys->{SERIALIZED_CACHE};

    return undef if (not $self->init ());

    return $self;
}

sub init
{
    my $self = shift;
    ##! 1: "start"

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

    if ($self->{serialized_cache}) {
        ##! 16: 'serialized cache exists, using it'
        my $ser = OpenXPKI::Serialization::Fast->new();
        $self->{cache} = $ser->deserialize($self->{serialized_cache});
        ##! 16: 'deserialized cache: ' . Dumper $self->{cache}
        return 1;
    }

    ##! 2: "load the XML data"
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
    ##! 2: "filename: $filename"

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
    ##! 64: 'cache: ' . Dumper $self->{cache}

    $self->{xtree}->{$filename}->{LEVEL} = 1;
    $self->{xtree}->{$filename}->{REF}   = $self->{cache};

    ##! 64: 'xtree: ' . Dumper $self->{xtree}
    $self->__perform_xinclude();
    ##! 64: 'cache after xinclude: ' . Dumper $self->{cache}
    $self->__perform_super_resolution();
    ##! 64: 'cache after super resolution: ' . Dumper $self->{cache}

    return 1;
}

sub get_serialized {
    my $self = shift;

    my $ser = OpenXPKI::Serialization::Fast->new();
    return $ser->serialize($self->{cache});
}

sub __super_tags_found {
    my $self      = shift;
    my $start_ref = shift;
    ##! 1: 'start'

    my $found = 0;
   SEARCH_FOR_SUPER:
    foreach my $entry (@{$start_ref}) {
        ##! 16: 'entry: ' . Dumper $entry
        if (exists $entry->{'super'}) {
            ##! 16: 'super tag found, exiting loop'
            $found = 1;
            last SEARCH_FOR_SUPER;
        }
        ##! 16: 'super attribute does NOT exist, scanning each key'
        my @keys = keys %{ $entry };
        ##! 16: 'keys: ' . Dumper \@keys
        
        foreach my $key (@keys) {
            ##! 16: 'key: ' . $key
            if (ref $entry->{$key} eq 'ARRAY') {
                # dig deeper if it is an array
                my $result = $self->__super_tags_found($entry->{$key});
                if ($result) {
                    ##! 16: 'super tag found'
                    $found = 1;
                    last SEARCH_FOR_SUPER;
                }
            }
        }
    }

    ##! 1: 'end: ' . $found
    return $found;
};

sub __get_super_entry {
    my $self  = shift;
    my $path  = shift;
    my $level = shift;

    my @path = split q{/}, $path;
    ##! 32: 'path: ' . Dumper \@path
    my $result = $self->{cache};

   PATH_TRAVERSAL:
    foreach my $element (@path) {
        my ($attribute, $id_attr, $id_content)
            = $self->__parse_super_element_entry($element);
        ##! 32: 'result: ' . Dumper $result
        ##! 16: 'attribute: '  . $attribute
        ##! 16: defined $id_attr ? 'id_attr: ' . $id_attr : '! id_attr'
        ##! 16: defined $id_content ? 'id_content: ' . $id_content : '! id_content'

        if (! defined $id_attr) {
            ##! 16: 'id_attr is undefined, just using the first one - if there is only one!'
            if (scalar @{ $result->{$attribute} } > 1) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_XML_CACHE___GET_SUPER_ENTRY_MORE_THAN_ONE_PATH_AND_NO_ID_SPECIFIED',
                    params  => {
                        ATTRIBUTE => $attribute,
                    },
                );
            }
            $result = $result->{$attribute}->[0];
            next PATH_TRAVERSAL;
        }

        my $entry_found = 0;
       FIND_ENTRY:
        foreach my $possible_path (@{$result->{$attribute}}) {
            ##! 32: 'possible path: ' . Dumper $possible_path
            if (exists $possible_path->{$id_attr} 
                && $possible_path->{$id_attr} eq $id_content) {
                ##! 32: 'matching entry found'
                $result = $possible_path;
                $entry_found = 1;
                last FIND_ENTRY;
            }
        }
        if (! $entry_found) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_XML_CACHE_GET_SUPER_ENTRY_PATH_NOT_FOUND',
                params  => {
                    'PATH'    => $path,
                    'ELEMENT' => $element,
                },
            );
        }
    }
    # copy result so that changing things in the new structure does
    # not break the one from which we inherited ...
    # Also replace any super tags in the structure we found (so that
    # local references get resolved there and not at the new place
    # later, which will not work)
    my $result_copy;
    if (exists $result->{'super'}) {
        ##! 16: 'super tag found at "toplevel"'
        ##! 16: 'result: ' . Dumper $result
        ##! 16: 'level: ' . ($level + 1)
        ##! 16: 'path: '  . $path
        $result_copy = $self->__replace_super({
            START_REF => [ $result ],
            PATH      => $path,
            LEVEL     => $level + 1,
        })->[0];
        return $result_copy;
    }

    foreach my $key (keys %{$result}) {
        if (ref $result->{$key} eq 'ARRAY' && $self->__super_tags_found($result->{$key})) {
            ##! 16: 'calling replace super ...'
            ##! 16: 'result->{$key}: ' . Dumper $result->{$key}
            $result_copy->{$key} = $self->__replace_super({
                START_REF => $result->{$key},
                LEVEL     => $level + 1,
                PATH      => $path . '/' . $key,
            });
            ##! 16: 'result_copy->{$key}: ' . Dumper $result_copy->{$key}
        }
        else {
            $result_copy->{$key} = $result->{$key};
        }
    }
    return $result_copy;
}

sub __parse_super_element_entry {
    my $self    = shift;
    my $element = shift;
    ##! 32: 'element: ' . $element

    # entry is of the form
    #           attribute                         (0)
    #           attribute{id_content} or          (1)
    #           attribute{id_attr:id_content}     (2)

    if (! ($element =~ /{/)) {
        ##! 16: 'element is of form 0'
        return ($element, undef, undef);
    }

    my $attribute;
    my $id_attr = 'id';
    my $id_content;

    if ($element =~ /:/) {
        ##! 16: 'element is of form 2'
        ($attribute, $id_attr, $id_content) = 
            ($element =~ m/ ([^{]+) { (\w+) : ([\w\*\ ]+) }/xms);
    }
    else {
        ##! 16: 'element is of form 1'
        ($attribute, $id_content) =
            ($element =~ m/ ([^{]+) { (\w+) }/xms);
    }
    if (! defined $attribute 
     || ! defined $id_attr
     || ! defined $id_content) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_XML_CACHE_PARSE_SUPER_ELEMENT_ENTRY_ERROR_PARSING_PATH_ELEMENT',
            params  => {
                ELEMENT => $element,
            },
        );
    }
    return ($attribute, $id_attr, $id_content);
}

sub __replace_super {
    my $self      = shift;
    my $arg_ref   = shift;
    my $start_ref = $arg_ref->{START_REF};
    my $path      = "$arg_ref->{PATH}";
    my $level     = $arg_ref->{LEVEL};
    my $MAX_LEVEL = 500;
    ##! 1: 'path: ' . $path
    ##! 1: 'level: ' . $level
    ##! 16: 'start_ref: ' . Dumper $start_ref

    if ($level > $MAX_LEVEL) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_XML_CACHE_REPLACE_SUPER_LEVEL_TOO_DEEP_POSSIBLE_SUPER_LOOP',
        );
    }

    foreach my $entry (@{$start_ref}) {
        ##! 16: 'entry: ' . Dumper $entry
        if (exists $entry->{'super'}) {
            ##! 16: 'super attribute exists, replacing content'
            ##! 16 red on_yellow: 'super entry is: ' . $entry->{'super'}
            ##! 16 bold blue on_white: 'current path is: ' . $path
            
            my $absolute_path_to_super;
            if ($entry->{'super'} =~ m{\A \.\.}xms) {
                ##! 16: 'super entry is relative, compute absolute path'
                $absolute_path_to_super = $path;
                my $relative_path = $entry->{'super'};
                while ($relative_path =~ s{\A \.\./}{}xms) {
                    ##! 16: 'cut off ../ from relative_path: ' . $relative_path
                    if (! $absolute_path_to_super) {
                        # if absolute path is empty already, we can not
                        # delete anything from it -> Exception
                        # this means that some has specified ../ below
                        # root
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_XML_CACHE_RELATIVE_TOO_MANY_LEVELS_UP',
                            params => {
                                'SUPER' => $entry->{super},
                                'RELATIVE_PATH' => $relative_path,
                            },
                        );
                    }
                    $absolute_path_to_super =~ s{/? [^/]+ \z}{}xms;
                    ##! 16: 'cut off last part from absolute_path_to_super: ' . $absolute_path_to_super
                }
                if ($absolute_path_to_super) {
                    # we still have absolute path left, append relative path with /
                    $absolute_path_to_super .= '/' . $relative_path;
                }
                else {
                    # the absolute path is the rest of the relative path
                    $absolute_path_to_super = $relative_path;
                }
                ##! 16: 'absolute_path_to_super: ' . $absolute_path_to_super
            }
            else {
                ##! 16: 'super entry is absolute, just use that'
                $absolute_path_to_super = $entry->{'super'};
            }
            # copy the entry to $original_entry (because we want to
            # copy everything except the super part back later)
            
            my $original_entry = {};
            $self->__deepcopy($entry, $original_entry);
            
            delete $original_entry->{'super'};
            ##! 32: 'original_entry: ' . Dumper $original_entry

            my $new_entry = {};
            # overwrite entry with the inherited one from super
            $self->__deepcopy(
                $self->__get_super_entry(
                    $absolute_path_to_super,
                    $level,
                ),
                $new_entry,
            );
            ##! 32: 'new entry after copying from super: ' . Dumper $new_entry
            ##! 32: 'copying back from original entry: ' . Dumper $original_entry
            ##! 32: 'keys of original entry: ' . Dumper keys %{$original_entry}
            # overwrite entries from the original entry
            $self->__deepcopy($original_entry, $new_entry);
            $self->__deepcopy($new_entry, $entry);
            delete $entry->{'super'};
            ##! 32: 'final entry after inheritance: ' . Dumper $entry
        }
        else {
            ##! 16: 'super attribute does NOT exist, scanning each key'
            $entry = $self->__replace_super_foreach_arrayrefkey({
                ENTRY => $entry,
                PATH  => $path,
                LEVEL => $level,
            });
        }
    }
    ##! 16: 'end, start_ref: ' . Dumper $start_ref

    return $start_ref;
}

sub __deepcopy {
    ##! 1: 'start'
    my $self   = shift;
    my $source = shift;
    my $dest   = shift;
    ##! 32: 'source: ' . Dumper $source
    ##! 32: 'dest:   ' . Dumper $dest

    my @entries = ();
    if (ref $source eq 'HASH') {
        ##! 16: 'source is hashref'
        foreach my $key (keys %{$source}) {
            ##! 32: 'key: ' . $key
            if (ref $source->{$key} eq 'HASH'
             || ref $source->{$key} eq 'ARRAY') {
                ##! 64: 'source is arrayref or hashref, deepcopying'
                if (! defined $dest->{$key}) {
                    if (ref $source->{$key} eq 'HASH') {
                        ##! 64: 'dest->{$key} is not defined, replacing with empty hashref'
                        $dest->{$key} = { };
                    }
                    elsif (ref $source->{$key} eq 'ARRAY') {
                        ##! 64: 'dest->{$key} is not defined, replacing with empty arrayref'
                        $dest->{$key} = [ ];
                    }
                    else {
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_XML_CACHE_UNEXPECTED_DATA_STRUCTURE',
                        );
                    }
                }
                $self->__deepcopy($source->{$key}, $dest->{$key});
            }
            elsif (! ref $source->{$key}) {
                ##! 64: 'source is scalar, copying source: ' . $source->{$key} . ' to dest: ' . $dest->{$key}
                $dest->{$key} = $source->{$key};
            }
        }
    }
    elsif (ref $source eq 'ARRAY') {
        # Note that his not a 'general' deepcopy, but assumes that
        # dest and source have the same number of entries if source
        # is an arrayref. Luckily, this holds true for the structures
        # generated from XMLin ...
        ##! 16: 'source is arrayref'
        for (my $i = 0; $i < scalar @{ $source }; $i++) {
            ##! 32: 'copying entry ' . $i
            if (ref $source->[$i]) {
                ##! 32: 'source is non-scalar'
                if (! defined $dest->[$i]) {
                    if (ref $source->[$i] eq 'HASH') {
                        ##! 64: 'dest->[$i] is not defined, replacing with empty hashref'
                        $dest->[$i] = { };
                    }
                    elsif (ref $source->[$i] eq 'ARRAY') {
                        ##! 64: 'dest->[$i] is not defined, replacing with empty arrayref'
                        $dest->[$i] = [ ];
                    }
                    else {
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_XML_CACHE_UNEXPECTED_DATA_STRUCTURE',
                        );
                    }
                }
                $self->__deepcopy($source->[$i], $dest->[$i]);
            }
            else {
                ##! 32: 'dest is scalar'
                $dest->[$i] = $source->[$i];
            }
        }
    }
    return 1;
}


sub __replace_super_foreach_arrayrefkey {
    my $self    = shift;
    my $arg_ref = shift;
    my $entry   = $arg_ref->{'ENTRY'};
    my $path    = $arg_ref->{'PATH'};
    my $level   = $arg_ref->{'LEVEL'};
    
    my @keys = keys %{ $entry };
    ##! 16: 'keys: ' . Dumper \@keys
    
    foreach my $key (@keys) {
        ##! 16: 'key: ' . $key
        if (ref $entry->{$key} eq 'ARRAY') {
            my $new_path = $path;
            if (exists $entry->{id}) {
                ##! 32: 'entry->id exists: ' . $entry->{id}
                $new_path = $path . '{' . $entry->{id} . '}';
            }
            # dig deeper if it is an array
            ##! 16: 'level: ' . $level
            ##! 16: 'array found, digging deeper'
            ##! 16: 'new_path: ' . $new_path
            ##! 16: 'path: '     . $new_path
            ##! 16: 'calling replace_super with path: ' . $new_path . '/' . $key
            $entry->{$key} = $self->__replace_super({
                START_REF => $entry->{$key},
                PATH      => $new_path . '/' . $key,
                LEVEL     => $level + 1,
            });
        }
    }
    return $entry;
}

sub __perform_super_resolution {
    my $self = shift;
    ##! 1: 'start'

    # scan configuration for unresolved super references

    foreach my $key (keys %{$self->{cache}}) {
        my $i = 0;
       REPLACE_SUPER_TAGS:
        while ($self->__super_tags_found($self->{cache}->{$key})) {
            $self->__replace_super({
                START_REF => $self->{cache}->{$key},
                PATH      => $key,
                LEVEL     => 0, # this is mainly for better debug output
            });
            if ($i > 1000) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_XML_CACHE_PERFORM_SUPER_RESOLUTION_TOO_MANY_INTERATIONS_POSSIBLE_SUPER_LOOP',
                );
                last REPLACE_SUPER_TAGS;
            }
            $i++;
        }
    }

    ##! 1: 'end'
    return 1;
}

sub __perform_xinclude
{
    my $self = shift;
    my $MAX_LEVEL = 70;
    ##! 1: "start"

    ## scan configuration for unresolved xincludes

    my @xincludes = $self->__scan_xinclude ($self->{cache});
    return 1 if (not scalar @xincludes);
    ##! 2: "xinclude tag detected"

    ## include the XML stuff

    foreach my $xinclude (@xincludes)
    {
        ## find insert position for the new XML data
        ##! 4: "integrate loaded XML data into XML tree"
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
        ##! 4: "calculate filename from path $path"
        my $filename = $xinclude->{XPATH}->[$elements];
        if ($filename !~ /^\//)
        {
	    # relative path detected
	    my ($vol, $dir, $file) = File::Spec->splitpath( File::Spec->rel2abs($path) );
            $filename = File::Spec->catfile($dir, $filename);
        }

        ## load the xinclude file
        ##! 4: "load the included file $filename"
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
        ##! 4: "top element of $filename is $top"

        ## insert the data into the XML structure
        if (exists $ref->{$top})
        {
            $ref->{$top} = [ @{$ref->{$top}}, $xml->{$top}->[0] ];
        } else {
            $ref->{$top} = $xml->{$top};
        }

        ## store position of file in XML tree
        ##! 4: "store reference for the filename"
        $self->{xref}->{$ref}->{$top}->{scalar @{$ref->{$top}} -1} = $filename;
        $self->{xtree}->{$filename}->{REF}   = $ref;
        $self->{xtree}->{$filename}->{NAME}  = $top;
        $self->{xtree}->{$filename}->{POS}   = scalar @{$ref->{$top}} -1;
        $self->{xtree}->{$filename}->{LEVEL} = 0;
    }

    ## update the levels

    ##! 2: "update tree level of the different files"
    foreach my $file (keys %{$self->{xtree}})
    {
        $self->{xtree}->{$file}->{LEVEL}++;
        ##! 16: "LEVEL for $file: " . $self->{xtree}->{$file}->{LEVEL}
        ## loop detection
        ## protection against endless loops
        ##! 4: "check for loop"
        if ($self->{xtree}->{$file}->{LEVEL} > $MAX_LEVEL) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_XML_CACHE_PERFORM_XINCLUDE_POSSIBLE_LOOP_DETECTED",
                params  => {
                    "FILENAME" => $file
                },
            );
        }
    }

    ## resolve the new xincludes

    ##! 1: "start next round of xinclude detection - end of function"
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
    ##! 1: "start"

    ## scan hash for xi tags

    foreach my $key (keys %{$ref})
    {
        if ($key ne "xi:include")
        {
            next if (ref $ref->{$key} ne "ARRAY"); ## content
            ##! 8: "scanning tag $key"
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
            ##! 8: "xi:include tag present"
            for (my $i=0; $i < scalar @{$ref->{"xi:include"}}; $i++)
            {
                ## namespace must be correct
                if ($ref->{"xi:include"}->[$i]->{"xmlns:xi"} !~ /XInclude/i)
                {
                    ## FIXME: any ideas what we are missing here?
                    ##! 1: "this is an empty IF statement --> bug"
                }
                ##! 16: "xi:include tag correct"
                ## extracting data
                push @result, {XPATH   => [ $ref->{"xi:include"}->[$i]->{"href"} ],
                               COUNTER => [ $i ]};
                ##! 16: "file ".$ref->{"xi:include"}->[$i]->{"href"}." ready for include"
            }
            ## delete xinclude tags to avoid loops
            delete $ref->{"xi:include"};
        }
    }
    ##! 1: "end"
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

sub get_xpath_hashref {
    my $self = shift;
    my $keys = { @_ };
    ##! 1: 'start'

    my $item = $self->{cache};
    for (my $i = 0; $i < scalar @{$keys->{XPATH}}; $i++) {
        if (! defined $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]]) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_HASHREF_MISSING_ELEMENT",
                params  => {"XPATH" =>    $self->__get_serialized_xpath($keys),
                            "TAG"   =>    $keys->{XPATH}->[$i],
                            "POSITION" => $keys->{COUNTER}->[$i]});
        }
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
    }
    if (ref $item ne 'HASH') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_XML_CACHE_GET_XPATH_HASHREF_RESULT_NOT_A_HASHREF',
            params  => {
                'XPATH' => $self->__get_serialized_xpath($keys),
            },
        );
    }
    ##! 64: 'item: ' . Dumper $item
    my $copy = {};
    $self->__deepcopy($item, $copy);
    ##! 64: 'copy: ' . Dumper $item
    return $copy;
}

sub get_xpath
{
    my $self = shift;
    my $keys = { @_ };
    ##! 1: "start"

    my $item = $self->{cache};
    for (my $i=0; $i<scalar @{$keys->{XPATH}}; $i++)
    {
        ##! 4: "XPATH: ".$keys->{XPATH}->[$i]
        ##! 4: "COUNTER: ".$keys->{COUNTER}->[$i]

        ##! 8: $i+1 == scalar @{$keys->{XPATH}} ? 'length ok' : 'length NOT ok'
        ##! 8: exists $item->{$keys->{XPATH}->[$i]} ? 'exists ok' : 'exists NOT ok'
        ##! 8: ! ref $item->{$keys->{XPATH}->[$i]} ? '! ref ok' : '! ref NOT ok'
        ##! 8: $keys->{COUNTER}->[$i] == 0 ? 'counter ok' : 'counter NOT ok'
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
                ##! 16: "attribute request: ".$item->{$keys->{XPATH}->[$i]}
                return $item->{$keys->{XPATH}->[$i]};
            }
            else
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_ELEMENT",
                    params  => {
			"XPATH" =>    $self->__get_serialized_xpath($keys),
			"TAG"   =>    $keys->{XPATH}->[$i],
			"POSITION" => $keys->{COUNTER}->[$i]
		    },
		    log => {
			message => 'Missing config element (' . $keys->{XPATH}->[$i] . '; #' . $keys->{COUNTER}->[$i] . ') for xpath (' . $self->__get_serialized_xpath($keys) . ')',
			facility => 'system',
			priority => 'debug'
		    },
		    );
            }
        }
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
    }
    if (not exists $item->{content})
    {
        ## the tag is present but does not contain anything
        ## this is no error !
        ##! 4: "no content"
        return "";
    }
    #unpack/pack is too slow, try to use "use utf8;"
    ###! 99: "content: ".pack ("U0C*", unpack "C*", $item->{content})
    #return pack "U0C*", unpack "C*", $item->{content};

    ## WARNING: you need an utf8 capable terminal to see the correct characters
    ##! 99: "content: ".$item->{content}
    ##! 1: "end"
    return $item->{content};
}

sub get_xpath_list
{
    my $self = shift;
    ##! 1: "start"

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
    ##! 1: "start"

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
                params  => {
		    "XPATH"    => $self->__get_serialized_xpath($keys),
		    "TAG"      => $keys->{XPATH}->[$i],
		    "POSITION" => $keys->{COUNTER}->[$i]
		},
		log => {
		    message => 'Missing config count (' . $keys->{XPATH}->[$i] . '; #' . $keys->{COUNTER}->[$i] . ') for xpath (' . $self->__get_serialized_xpath($keys) . ')',
		    facility => 'system',
		    priority => 'debug'
		},
		);
        }
        $item = $item->{$keys->{XPATH}->[$i]}->[$keys->{COUNTER}->[$i]];
    }
    ##! 2: "scan complete"
    if (not exists $item->{$keys->{XPATH}->[scalar @{$keys->{COUNTER}}]})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_XML_CACHE_GET_XPATH_COUNT_NOTHING_FOUND",
            params  => {
                XPATH => $self->__get_serialized_xpath($keys),
            },
	    log => {
		message => 'Config entry does not exist for xpath (' . $self->__get_serialized_xpath($keys) . ')',
		facility => 'system',
		priority => 'debug'
	    },
        );
    }
    ##! 2: "at minimum one exists"
    $item = $item->{$keys->{XPATH}->[scalar @{$keys->{COUNTER}}]};
    ## this is a hack (internal feature) for get_xpath_list
    return $item if ($keys->{REF});
    ##! 2: "content: ".scalar @{$item}
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

sub xml_simple {
    my $self = shift;
    return $self->{cache};
}

1;
__END__

=head1 Name

OpenXPKI::XML::Cache - XML cache for configuration data.

=head1 Description

This class caches the complete XML configuration of OpenXPKI.

=head1 XML::Parser and XML::Simple

We enforce the usage of XML::Parser by XML::Simple because some other
parsers does not create an error if the XML document is malformed.
These parsers tolerate errors!

=head1 Functions

=head2 new

create the class instance and calls internally the function init to
load the XML files for the first time. The supported parameters are
CONFIG and SCHEMA.

=over

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
performance. The init function resolves both xincludes as well as
inheritance via super tags.

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

=head2 xml_simple

Returns the XML::Simple data structure.
