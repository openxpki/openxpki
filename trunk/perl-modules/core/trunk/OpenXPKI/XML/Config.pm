## OpenXPKI::XML::Config
##
## Written by Michael Bell for the OpenXPKI project
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## Copyright (C) 2003-2006 by The OpenXPKI Project
## $Revision$

package OpenXPKI::XML::Config;

use strict;
use warnings;
use utf8;

use OpenXPKI::XML::Cache;
use OpenXPKI::Debug 'OpenXPKI::XML::Config';
use OpenXPKI::Exception;
use English;

use Data::Dumper;
sub new
{ 
    my $that  = shift;
    my $class = ref($that) || $that;
  
    my $self = {};
   
    bless $self, $class;

    my $keys = { @_ };

    ##! 16: 'keys: ' . Dumper $keys

    $self->{CACHE} = OpenXPKI::XML::Cache->new (@_);

    return $self;
}

sub get_xpath
{
    my $self = shift;
    ##! 1: "start"

    my %keys = $self->__get_fixed_params(@_);
    ##! 16: 'keys: ' . Dumper \%keys

    return $self->{CACHE}->get_xpath( %keys );
}

sub get_xpath_list
{
    my $self = shift;
    ##! 1: "start"

    my %keys = $self->__get_fixed_params(@_);
    delete $keys{COUNTER}->[scalar @{$keys{COUNTER}}-1];

    return $self->{CACHE}->get_xpath_list (%keys);
}

sub get_xpath_count
{
    my $self = shift;
    ##! 1: "start"

    my %keys = $self->__get_fixed_params(@_);
    delete $keys{COUNTER}->[scalar @{$keys{COUNTER}}-1];

    return $self->{CACHE}->get_xpath_count (%keys);
}

sub __get_fixed_params
{
    my $self = shift;
    my $keys = { @_ };
    ##! 1: "start"

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
    ##! 2: "parameters serialized"

    ## normalize parameters for XML cache

    my %params = (XPATH => [], COUNTER => []);

    for (my $i=0; $i<scalar @xpath; $i++)
    {
        ##! 4: "scan: ".$xpath[$i]
        my @names = split /\//, $xpath[$i];
        foreach my $name (@names)
        {
            ##! 8: "part: $name"
            $params{XPATH}   = [ @{$params{XPATH}},   $name ];
            $params{COUNTER} = [ @{$params{COUNTER}}, 0 ];
        }
        ##! 4: "replaced counter"
        $params{COUNTER}->[scalar @{$params{COUNTER}} -1] = $counter[$i];
    }
    ##! 2: "xpath: ".join ", ", @{$params{XPATH}}
    ##! 2: "counter: ".join ", ", @{$params{COUNTER}}
    ##! 2: "parameters normalized"

    return %params;
}

sub dump
{
    my $self = shift;
    return $self->{CACHE}->dump (@_);
}

1;
__END__

=head1 Name

OpenXPKI::XML::Config - interface to configuration data.

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
The supported parameters are the same as for the XML cache.

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
