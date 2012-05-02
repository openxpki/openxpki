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
    
    my $result;
    my $cnt = $self->get( [ $prefix, 'resolvers'] );
    for (my $i = 0; $i < $cnt; $i++) {            
        my $resolver =  $self->get( [ $prefix, 'resolvers', $i ] );
        ##! 32: 'Ask Resolver ' . $prefix.'.'.$resolver.'.'.$query
        $result = $self->get( [ $prefix, $resolver, $query ]);
        return { 'value' => $result, 'source' => $resolver } if ($result);
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

  
