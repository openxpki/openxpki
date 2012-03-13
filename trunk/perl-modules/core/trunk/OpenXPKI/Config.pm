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

extends 'Connector::Multi';

has '+BASECONNECTOR' => ( required => 0 );

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
        
    my $dbpath = $ENV{OPENXPKI_CONF_DB} || '/etc/openxpki/config.git';    
    $dbpath = 'connector/config/config.git';
    
    my $cv = Connector::Proxy::Config::Versioned->new(
        {
            LOCATION  => $dbpath,            
        }
    ) or die "Error creating Config: $@";
        
    return $class->$orig( { BASECONNECTOR => $cv } );
};

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

  