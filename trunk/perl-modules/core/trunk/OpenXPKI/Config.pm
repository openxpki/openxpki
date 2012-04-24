# OpenXPKI::Config
#
# Written 2012 by Oliver Welter for the OpenXPKI project
# Copyright (C) 2012 by The OpenXPKI Project
#

package OpenXPKI::Config;

use strict;
use warnings;
use English;
use Moose;
use Connector::Proxy::Config::Versioned;
use OpenXPKI::Debug;

extends 'Connector::Multi';

has '+BASECONNECTOR' => ( required => 0 );

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
        
    my $dbpath = $ENV{OPENXPKI_CONF_DB} || '/etc/openxpki/config.git';    
    
    if (! -d $dbpath) {
        OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_INIT_TASK_GIT_DBPATH_DOES_NOT_EXIST",
		params  => {
		    dbpath => $dbpath,
		});
    }
    
    my $cv = Connector::Proxy::Config::Versioned->new(
        {
            LOCATION  => $dbpath,
        }
    );
    
    if (!$cv) {
        OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_INIT_TASK_CONFIG_LAYER_NOT_INITIALISED",
		params  => {
		    dbpath => $dbpath,
		});
    }
        
    return $class->$orig( { BASECONNECTOR => $cv } );
};

sub walkQueryPoints {
    
    my $self = shift;
    my $prefix = shift;
    my $query = shift;
    my $call = shift;
    
    $call = 'get' unless($call);    
    
    ##! 16: " Walk resolvers at $prefix with $call "
    
    my $result;    
    foreach my $resolver (  $self->get_list( [ $prefix, 'resolvers'] ) ) {                
        ##! 32: 'Ask Resolver ' . $prefix.'.'.$resolver.'.'.$query
        $result = $self->$call( [ $prefix, $resolver, $query ]);
        return { 'VALUE' => $result, 'SOURCE' => $resolver } if ($result);
    }    
    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__DATA__

=head1 NAME

OpenXPKI::Config - Connector based configuration layer using Config::Versioned

=head1 SYNOPSIS

 use OpenXPKI::Config;

 my $cfg = OpenXPKI::Config->new();

 print "Param1=", $cfg->get('subsystem1.group1.param1'), "\n";

=head1 DESCRIPTION

=head1 Methods

=head2 walkQueryPoints

Shortcut method to test multiple resolvers for a value.

=head3 parameters

=over 8
 
=item prefix 

The path where the resolver configuration is found. 

=item query

The query string to append to the path

=item call 

The call executed on each resolver node, possible values are all get_*
methods which are supported by the used connectors. The default is I<get>. 
  
=back

=head3 output

Returns a hash structure holding the result of the first non-empty call and 
the of the resolver which returned the result

   return { 'VALUE' => $result, 'SOURCE' => $resolver } 
   
To query the same path again, put the resolver name into the path: 

   my $value = $conn->get([ $prefix, $resolver, $query ])
   
=head3 configuration

You need to provide the list of resolvers as an ordered list along with
the data.

  mydata:
    resolvers:
     - testing
     - repo1
     - repo2
     
    testing: 
       foo: 1234
       bar: 5678
       
    repo1@: connector:connectors.primary-repo
    repo2@: connector:connectors.fallback-repo   
   
