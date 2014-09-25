# OpenXPKI::Config::Backend
#
# Reads in the base configuration from the /etc/openxpki/config.d path
# using Config::Merge, converts the "@" syntax to scalar links (as expected
# by Connector::Multi and puts anything into a memory based connector
# The instance is passed as baseconnector to OpenXPKKI::Config as a replacement
# for Config::Versioned
#
# vim: syntax=perl

package OpenXPKI::Config::Backend;

use Config::Merge;
use OpenXPKI::XML::Cache;
use Data::Dumper;

use Moose;
extends 'Connector::Builtin::Memory';

has '+LOCATION' => (
    required => 0,
    default => '/etc/openxpki/config.d'
);

sub _build_config {

    my $self = shift;

    # Environment always wins
    if ( $ENV{OPENXPKI_CONF_PATH} ) {
        $self->LOCATION(  $ENV{OPENXPKI_CONF_PATH} );
    }

    # Skip the workflow directories
    my $cm    = Config::Merge->new( path => $self->LOCATION(), skip => qr/realm\.\w+\._workflow/ );
    my $cmref = $cm->();

    my $tree = $self->cm2tree($cmref);

    # Incorporate the Workflow XML definitions
    # List the realms from the system.realms tree
    foreach my $realm (keys %{$tree->{system}->{realms}}) {
        # TODO - MIGRATION - We load the xml code now to workflow.xml
        my $xml_cache = OpenXPKI::XML::Cache->new (CONFIG => $self->LOCATION()."/realm/$realm/_workflow/workflow.xml");
        $tree->{realm}->{$realm}->{workflow}->{xml} = $xml_cache->get_serialized();
    }

    return $tree;

}

# cm2tree is just a helper routine for recursively traversing the data
# structure returned by Config::Merge and massaging it into something
# we can use with Config::Versioned

sub cm2tree {
    my $self = shift;
    my $cm   = shift;
    my $tree = {};

    if ( ref($cm) eq 'HASH' ) {
        my $ret = {};
        foreach my $key ( keys %{$cm} ) {
            if ( $key =~ m{ (?: \A @ (.*?) @ \z | \A @ (.*) | (.*?) @ \z ) }xms ) {
                my $match = $1 || $2 || $3;
                # make it a ref to an anonymous scalar so we know it's a symlink
                $ret->{$match} = \$cm->{$key};
            } else {
                $ret->{$key} = $self->cm2tree( $cm->{$key} )
            }
        }
        return $ret;
    }
    elsif ( ref($cm) eq 'ARRAY' ) {
        my $ret = [];
        my $i = 0;
        foreach my $entry ( @{$cm} ) {
            $ret->[ $i++ ] = $self->cm2tree($entry);
        }
        return $ret;
    }
    else {
        return $cm;
    }
}

1;    # End of OpenXPKI::Config

__DATA__


=head1 NAME

OpenXPKI::Config::Backend - Backend connector holding the system config

=head1 SYNOPSIS

 use OpenXPKI::Config::Memory;

 my $cfg = OpenXPKI::Config::Memory->new();


=head1 DESCRIPTION

This connector serves as the backend to provide the initial configuration data
which is held in the /etc/openxpki/config.d directory. On startup, it reads in
all files found in the directory and parses them using Config::Merge. The
result is store using Connector::Builtin::Memory, keys starting/ending with the
"@" sign are converted to "reference links" as understood by Connector::Multi.

=head1 CONFIGURATION

The class does not require any configuration. You can set the base the path to
the config root using the environment variable C<OPENXPKI_CONF_PATH>. The class
will also accept the LOCATION attribute inside the constructor as root.

