## OpenXPKI::XML::Config
##
## Written by Michael Bell for the OpenXPKI project
## Copyright (C) 2003-2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::XML::Config;

use OpenXPKI::XML::Cache;
use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use English;

# use Smart::Comments;

sub new
{ 
    my $that  = shift;
    my $class = ref($that) || $that;
  
    my $self = {DEBUG => 0};
   
    bless $self, $class;

    my $keys = { @_ };

    $self->{DEBUG} = $keys->{DEBUG} if ($keys->{DEBUG});
    $self->{CACHE} = OpenXPKI::XML::Cache->new (@_);

    return $self;
}

sub get_xpath
{
    my $self = shift;
    $self->debug ("start");

    my %keys = $self->__get_fixed_params(@_);

    my $return = eval {$self->{CACHE}->get_xpath (%keys)};
    if ($EVAL_ERROR)
    {
        return $self->get_xpath ($self->__get_super_xpath(%keys));
    } else {
        delete $self->{SUPER_CACHE};
        return $return;
    }
}

sub get_xpath_list
{
    my $self = shift;
    $self->debug ("start");

    my %keys = $self->__get_fixed_params(@_);
    delete $keys{COUNTER}->[scalar @{$keys{COUNTER}}-1];

    my $return = eval {$self->{CACHE}->get_xpath_list (%keys)};
    if ($EVAL_ERROR)
    {
        return $self->get_xpath_list ($self->__get_super_xpath(%keys));
    } else {
        delete $self->{SUPER_CACHE};
        return $return;
    }
}

sub get_xpath_count
{
    my $self = shift;
    $self->debug ("start");

    my %keys = $self->__get_fixed_params(@_);
    delete $keys{COUNTER}->[scalar @{$keys{COUNTER}}-1];

    my $return = eval {$self->{CACHE}->get_xpath_count (%keys)};
    if ($EVAL_ERROR)
    {
        return $self->get_xpath_count ($self->__get_super_xpath(%keys));
    } else {
        delete $self->{SUPER_CACHE};
        return $return;
    }
}

sub __get_fixed_params
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    ## first make all parameters well-formed arrays

    my @xpath   = ();
    my @counter = ();
    if (not exists $keys->{XPATH})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_XML_CONFIG_GET_FIXED_PARAMS_MISSING_XPATH");
    }
    if (ref $keys->{XPATH})
    {
        @xpath = @{$keys->{XPATH}};
    }
    else
    {
        @xpath = ( $keys->{XPATH} );
    }
    if (not exists $keys->{COUNTER})
    {
        $keys->{COUNTER} = [0];
    }
    if (ref $keys->{COUNTER})
    {
        @counter = @{$keys->{COUNTER}};
    }
    else
    {
        @counter = ( $keys->{COUNTER} );
    }
    @counter = ( @counter, 0 ) if (scalar @counter < scalar @xpath);
    if (scalar @counter < scalar @xpath)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_XML_CONFIG_GET_FIXED_PARAMS_MISSING_COUNTER");
    }
    $self->debug ("parameters serialized");

    ## normalize parameters for XML cache

    my %params = (XPATH => [], COUNTER => []);

    for (my $i=0; $i<scalar @xpath; $i++)
    {
        $self->debug ("scan: ".$xpath[$i]);
        my @names = split /\//, $xpath[$i];
        foreach my $name (@names)
        {
            $self->debug ("part: $name");
            $params{XPATH}   = [ @{$params{XPATH}},   $name ];
            $params{COUNTER} = [ @{$params{COUNTER}}, 0 ];
        }
        $self->debug ("replaced counter");
        $params{COUNTER}->[scalar @{$params{COUNTER}} -1] = $counter[$i];
    }
    if ($self->{DEBUG})
    {
        $self->debug ("xpath: ".join ", ", @{$params{XPATH}});
        $self->debug ("counter: ".join ", ", @{$params{COUNTER}});
    }
    $self->debug ("parameters normalized");

    return %params;
}

sub dump
{
    my $self = shift;
    return $self->{CACHE}->dump (@_);
}

sub __get_super_xpath
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    my @xpath   = @{$keys->{XPATH}};
    my @counter = @{$keys->{COUNTER}};

    my @new_xpath;
    my @new_counter;

    ## put the last element into the new path
    unshift @new_xpath, pop(@xpath);

    if (scalar @xpath < scalar @counter)
    {
	unshift @new_counter, pop(@counter);
    }

    ## start scanning for a super attribute

    $self->debug ("scanning for super attribute");
    my $super = "";
    while (not $super and scalar @xpath)
    {
        my $tmp_xpath   = [@xpath,   "super"];
        my $tmp_counter = [@counter, 0];
        $super = eval {$self->{CACHE}->get_xpath (XPATH   => $tmp_xpath,
                                                  COUNTER => $tmp_counter)};
        if ($EVAL_ERROR or not length $super)
        {
            ## go to the next element of the path
            $super = "";

	    unshift @new_xpath, pop(@xpath);
	    unshift @new_counter, pop(@counter);
        } else {
            ## found super reference, so nothing to do
        }
    }

    if (not $super)
    {
        $super = "";
        for (my $i=0; $i<scalar @new_xpath; $i++)
        {
            $super .= "/" if (length $super);
	    my $counter = $new_counter[$i];
	    if (! defined $counter) {
		$counter = "undef";
	    }
            $super .= $new_xpath[$i] . "[$counter]";
        }
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_XML_CONFIG_GET_SUPER_XPATH_NO_INHERITANCE_FOUND",
            params  => {XPATH => $super});
    }
    if (exists $self->{SUPER_CACHE} and
        exists $self->{SUPER_CACHE}->{$super})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_XML_CONFIG_GET_SUPER_XPATH_LOOP_BY_SUPER_FOUND",
            params  => {"SUPER" => $super});
    }
    else
    {
        $self->{SUPER_CACHE}->{$super} = 1;
    }
    $self->debug ("super is $super");

    ## build the new path prefix

    my @super_list    = split m{\/}, $super;
    my @super_xpath   = ();
    my @super_counter = ();

    ### ----------------------- start...
    ### keys: $keys
    ### super list: @super_list
    ### @xpath
    ### @counter

    # handle relative paths
    if ($super_list[0] =~ m{\A \.\.}xms) {
	### identified relative specification
	@super_xpath   = @xpath;
	@super_counter = @counter;
#	pop @super_xpath;
#	pop @super_counter;
    }


    foreach my $item (@super_list)
    {
	### checkpoint 1...
	### $item
        my $path = $item;
        $path =~ s{ \{ .* }{}xms;
	my ($parent_id) = ($item =~ m{ \{ (.*?) \} }xms);

	### $path
	### $parent_id
	### @super_xpath
	### @super_counter


	if ($path ne '..') {
	    push @super_xpath, $path;
	} else {
	    # one level up
	    pop @super_xpath;
	    pop @super_counter;
	    pop @super_counter;
	}
	
	### checkpoint 2...
	### @super_xpath
	### @super_counter

        if (defined $parent_id)
        {
	    my $idtag = 'id';
	    if ($parent_id =~ m{ (.*?):(.*) }xms) {
		$idtag     = $1;
		$parent_id = $2;
	    }
	    
	    ### checkpoint 3...
	    ### idtag: $idtag
	    ### parent_id: $parent_id
	    
            ## how many possible jump targets exist?
            my $count = $self->{CACHE}->get_xpath_count (
                            XPATH   => [@super_xpath],
                            COUNTER => [@super_counter]);

            ## scan for the id
            my $target = $count;
            for (my $i=0; $i < $count; $i++)
            {
                my $id = eval {$self->get_xpath (XPATH   => [@super_xpath, $idtag ],
                                                 COUNTER => [@super_counter, $i, 0])};
                next if ($EVAL_ERROR);
                next if ($id ne $parent_id);
                $target = $i;
                $i = $count;
            }
            if ($target == $count)
            {
                ## jump id does not exist
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_XML_CONFIG_GET_SUPER_XPATH_WRONG_SUPER_REFERENCE",
                    params  => {"SUPER" => $super});
            }
	    push @super_counter, $target;
        }
        else
        {
	    # no super attribute defined -> use the first one
	    push @super_counter, 0;
        }
	### checkpoint 4...
	### @super_xpath
	### @super_counter
    }
    $self->debug ("super_xpath is ".join "/", @super_xpath);
    $self->debug ("super_counter is ".join "/", @super_counter);

    ## concatenate the two paths
    ### checkpoint 5...
    ### @new_xpath
    ### @new_counter
    ### @super_xpath
    ### @super_counter

    push @super_xpath, @new_xpath;
    push @super_counter, @new_counter;
    $self->debug ("new xpath is ".join "/", @super_xpath);
    $self->debug ("new counter is ".join "/", @super_counter);

    ### checkpoint 6...
    ### @new_xpath
    ### @new_counter
    ### @super_xpath
    ### @super_counter
    ### -------------------finished...

    return (XPATH => [@super_xpath], COUNTER => [@super_counter]);
}

1;
__END__

=head1 Description

The config module is a layer directly above the XML cache. The layer has
two jobs. It provides the programmers with a comfortable interface which
allows several simplifications for the use of the XML cache. The second
feature which will be implemented later is configuration inheritance.
The configuration inheritance will allow you to inherit the
configuration from other sections.

=head1 Inheritance and Path Discovery

We only implement a very simple inheritance algorithm. If we do not find
a specified path then we go back this path until we find a super attribute
in a XML tag. After this we start the question again with the path from
the super attribute plus the original search path below the super
attribute carrying tag. A simple loop detection which is based on the
super attributes is present.

=head1 Functions

=head2 new

create the class instance and instantiates the XML cache.
The supported parameters are the same as for the XML cache. The function
itself only uses the parameter DEBUG.

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

The interface is exactly the same like for get_xpath with one big
exception. COUNTER is always one element shorter than XPATH. The
result is the number of available values with the specified path.

=head2 get_xpath_list

The interface is the same like for get_xpath_count. Only the return
value is different. It returns an array reference to the found
values.

=head2 dump

This call is directly passed to the XML cache.
