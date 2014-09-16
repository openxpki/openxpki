## OpenXPKI::Config
##
## Written 2011 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2010, 2011 by The OpenXPKI Project
##
## Based on the CPAN module App::Options
##
## vim: syntax=perl

use Config::Merge;
use OpenXPKI::Exception;
use OpenXPKI::XML::Cache;

package OpenXPKI::Config::Merge;

use base qw( Config::Versioned );

# override new() to prepend with our config bootstrap
sub new {
    my ($this) = shift;
    my $class = ref($this) || $this;
    my $params = shift;

    # Set from ENV
    $params->{dbpath} = $ENV{OPENXPKI_CONF_DB} if ($ENV{OPENXPKI_CONF_DB});
    $params->{path} = [ split( /:/, $ENV{OPENXPKI_CONF_PATH} ) ] if ( $ENV{OPENXPKI_CONF_PATH} );

    # Set to defaults if nothing is set
    $params->{dbpath} = '/etc/openxpki/config.git' unless($params->{dbpath});
    $params->{path} = [qw( /etc/openxpki/config.d )] if ( not exists $params->{path} );

    $params->{autocreate} = 1;
    $this->SUPER::new($params);
}

# parser overrides the method in Config::Versioned to use Config::Merge
# instead of Config::Std
# TODO: Parse multiple directories

sub parser {
    my $self   = shift;
    my $params = shift;

    my $dir;
    if ( exists $params->{'path'} ) {
        $dir = $params->{path}->[0];
    } else {
        $dir = $self->path()->[0];
    }

    # If the directory was not set or doesn't exist, don't bother
    # trying to import any configuration
    if ( not $dir or not -d $dir ) {
        return;
    }

    # Skip the workflow directories
    my $cm    = Config::Merge->new( path => $dir, skip => qr/realm\.\w+\._workflow/ );
    my $cmref = $cm->();

    my $tree = $self->cm2tree($cmref);

    # Incorporate the Workflow XML definitions
    # List the realms from the system.realms tree
    foreach my $realm (keys %{$tree->{system}->{realms}}) {
        # TODO - MIGRATION - We load the xml code now to workflow.xml
        my $xml_cache = OpenXPKI::XML::Cache->new (CONFIG => "$dir/realm/$realm/_workflow/workflow.xml");
        $tree->{realm}->{$realm}->{workflow}->{xml} = $xml_cache->get_serialized();
    }
    $params->{comment} = 'import from ' . $dir . ' using Config::Merge';
    $self->commit( $tree, @_, $params );
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
                #make it a ref to an anonymous scalar so we know it's a symlink
                $ret->{$match} = \$cm->{$key};
            } else {
                $ret->{$key} = $self->cm2tree( $cm->{$key} )
            }
        }
        return $ret;
    }
    elsif ( ref($cm) eq 'ARRAY' ) {
        my $ret = {};
        my $i   = 0;
        foreach my $entry ( @{$cm} ) {
            $ret->{ $i++ } = $self->cm2tree($entry);
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

OpenXPKI::Config - Simplified access to the configuration data

=head1 SYNOPSIS

 use OpenXPKI::Config;

 my $cfg = OpenXPKI::Config->new();

 print "Param1=", $cfg->get('subsystem1.group1.param1'), "\n";

=head1 DESCRIPTION

OpenXPKI::Config uses Config::Versioned to access versioned configuration
parameters. It overrides the default behavior of Config::Versioned to use
the CPAN C<Config::Merge> module instead of C<Config::Std>. In addition,
the following parameters are also modified:

=head2 dbpath

The C<dbpath> (the storage location for the internal git repository) is
located in C</etc/openxpki/config.git> by default, but may be overridden
with the ENV variable C<OPENXPKI_CONF_DB>.

=head2 path

The C<path> is where the configuration files to be read are located and
is set to C</etc/openxpki/config.d> by default, but may be overridden
with the ENV variable C<OPENXPKI_CONF_PATH>.

Note: for C<Config::Merge>, only one directory name should be supplied
and not a colon-separated list.


=head1 METHODS

=head2 new()

This overrides the parent class, adding the default locations for the
configuration files needed by OpenXPKI.

=head1 MORE INFO

See L<Config::Versioned> for more details on the configuration backend.

See L<Config::Merge> for more details on the configuration file format.

=cut

1;

