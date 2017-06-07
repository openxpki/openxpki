package OpenXPKI::Config::Backend;

use Config::Merge;
use Data::Dumper;

use Moose;
extends 'Connector::Builtin::Memory';

around BUILDARGS => sub {
    my ($orig, $class, %params) = @_;

    # Environment always wins
    $params{LOCATION} = $ENV{OPENXPKI_CONF_PATH} if $ENV{OPENXPKI_CONF_PATH};

    return $class->$orig(%params);
};

sub _build_config {
    my $self = shift;

    # Skip the workflow directories
    my $cm    = Config::Merge->new( path => $self->LOCATION, skip => qr/realm\.\w+\._workflow/ );
    my $cmref = $cm->();

    my $tree = $self->cm2tree($cmref);

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

1;

__DATA__


=head1 NAME

OpenXPKI::Config::Backend - Backend connector holding the system config

=head1 SYNOPSIS

    use OpenXPKI::Config::Backend;

    my $cfg = OpenXPKI::Config::Backend->new(LOCATION => "/etc/openxpki/config.d");


=head1 DESCRIPTION

This connector serves as the backend to provide the initial configuration data
which is held in the directory given via I<LOCATION> parameter. On startup, it
reads all files found in the directory and parses them using
L<Config::Merge>. The result is stored using
L<Connector::Builtin::Memory>, keys starting/ending with the "@" sign are
converted to "reference links" as understood by L<Connector::Multi>.

=head1 CONFIGURATION

The class does not require any configuration. You can set the base the path to
the config root using the environment variable C<OPENXPKI_CONF_PATH>. This will
overwrite the I<LOCATION> attribute given to the constructor.
