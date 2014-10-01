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
use OpenXPKI::Config::Backend;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;

# Make sure the underlying connector is recent
use Connector 1.08;

extends 'Connector::Multi';

has '+BASECONNECTOR' => ( required => 0 );

has '_head_version' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
    default => '',
);


around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    return $class->$orig( { BASECONNECTOR => OpenXPKI::Config::Backend->new() } );
};

before '_route_call' => sub {

    my $self = shift;
    my $call = shift;
    my $path = shift;
    my $location;

    # Location can be a string or an array
    if (ref $path eq "ARRAY") {
        $location = @{$path}[0];
        ##! 8: 'Location was array - shifted: ' . Dumper $location
    } else {
        $location = $path;
    }

    ##! 16: "_route_call interception on $location "
    # system or realm acces - no prefix
    if ( substr ($location, 0, 6) eq 'system' || substr($location, 0, 5) eq 'realm' ) {
        ##! 16: "_route_call: system or explicit realm value, reset connector offsets"
        $self->_config()->{''}->PREFIX('');
    } else {
        my $session = CTX('session');
        my $pki_realm = $session->get_pki_realm();
        ##! 16: "_route_call: realm value, set prefix to " . $pki_realm
        $self->_config()->{''}->PREFIX( "realm.$pki_realm" );
    }

    ##! 8: 'Full path: ' . Dumper $path
};

sub get_version {
    my $self = shift;
    return '';
    ##! 16: 'Config version requested ' . Dumper( $self->BASECONNECTOR()->version() )
    #return $self->BASECONNECTOR()->version();
}

sub get_head_version {
    my $self = shift;
    return '';
    #return $self->_head_version();
}

sub update_head {
    my $self = shift;

    return '';

    my $head_id = $self->BASECONNECTOR()->fetch_head_commit();

    # if the head version has evolved, update the session context
    ##! 32: sprintf 'My head: %s,  Repo head: %s ',  $self->_head_version(), $head_id
    if ( $self->_head_version() ne $head_id ) {
        ##! 16: 'Advance to head commit ' . $head_id
        $self->_head_version( $head_id );

        CTX('log')->log(
            MESSAGE  => "system config advanced to new head commit: $head_id",
            PRIORITY => "info",
            FACILITY => "system",
        );

        return 1;
    }
    return;
}

sub walkQueryPoints {

    my $self = shift;
    my $prefix = shift;
    my $query = shift;
    my $params = shift;

    my $call;

    if (ref $params eq 'HASH') {
        $call = $params->{call};
        undef $params->{call};
    } elsif ($params) {
        $call = $params;
    } else {
        $call = 'get';
    }

    ##! 16: " Walk resolvers at $prefix with $call "

    my $result;

    my @path_prefix = $self->_build_path( $prefix );
    my @prep_query = $self->_build_path( $query );

    foreach my $resolver (  $self->get_list( [ @path_prefix, 'resolvers' ] ) ) {
        ##! 32: 'Ask Resolver ' . $prefix.'.'.$resolver.'.'.$query
        $result = $self->$call( [ @path_prefix, $resolver, @prep_query ] , $params );
        return { 'VALUE' => $result, 'SOURCE' => $resolver } if ($result);
    }
    return;
}

sub get_scalar_as_list {
    my $self = shift;
    my $path = shift;
    my @values;
    my $meta = $self->get_meta( $path );

    return unless(defined $meta);

    ##! 16: 'node meta ' . Dumper $meta
    if ($meta->{TYPE} eq 'list') {
        @values = $self->get_list( $path );
    } elsif ($meta->{TYPE} eq 'scalar') {
        my $val = ( $self->get( $path ) );
        @values = ( $val ) if (defined $val);
    } else {
        CTX('log')->log(
            MESSAGE  => "get_scalar_as_list got invalid node type",
            PRIORITY => "error",
            FACILITY => "system",
        );
    }
    ##! 16: 'values ' . Dumper @values
    return @values;
}

sub get_inherit {

    ##! 1: 'start'
    my $self = shift;
    my $path = shift;
    my $val;

    # Shortcut - check if the full path exists
    $val = $self->get($path);
    return $val if (defined $val);

    # Path does not exist - look for "inherit" keyword
    my ($pre, $section, $key);
    my @prefix;

    if (ref $path eq "") {
        $path =~ /^(.*)\.([\w-]+)\.([\w-]+)$/;
        $key = $3;
        $section = $2;
        @prefix = $self->_build_path( $1 );
    } else {
        my @path = @{$path};
        $key = pop @path;
        $section = pop @path;
        @prefix = @path;
    }

    ##! 16: "split path $prefix - $section - inherit"

    $section = $self->get( [ @prefix , $section, 'inherit' ] );
    while ($section) {
        ##! 16: 'Section ' . $section
        $val = $self->get( [ @prefix , $section, $key ]);
        return $val if (defined $val);
        $section = $self->get( [ @prefix , $section, 'inherit' ] );
   }

    ##! 8: 'nothing found'
    return undef;

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

The new config layer can be seen as a three dimensional system, where the
axes are path, version and realm. The path is passed in as parameter to the
I<get_*> methods inherited from the parent class Connector::Multi.

Version and realm are automagically set from the session context.
The version equals to the commit hash of the Config::Versioned base
repository. The realm is prepended to the path.

Therefore,a call to I<subsystem1.group1.param1> is resolved to the node
I18N_OPENXPKI_DEPLOYMENT_MY_REALM_ID.subsystem1.group1.param1.

Exception: The namespace B<system> is a reserved word and is not affected by
version/realm mangling. A call to a value below system is always executed on
the current head version and the root context.

=head1 Methods

=head2 update_head

The commit id of the head is determined at startup. Changes to the config
repository during runtime are not visible to the connector. This method
updates the internal head pointer to the current head of the underlying
repository.

Returns true if the head has changed, false otherwise.

=head2 get_version

Return the sha1 value of the current head of the config tree.
This is the version which is used, when you dont pass a version or
when you query a value in the C<system> namespace.

=head2 get_head_version

Return the sha1 value of the latest commit of the config tree.

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

   my $value = $conn->get( "$prefix.$resolver.$query" )

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

=head2 get_inherit

Fetch a single value from a block using inheritance (like the crypto config).

The query

    $conn->get_inherit('token.ca-one-signer.backend')

will lookup the C<inherit> key and use the value to replace the next-to-last
path component with it to look up the value again. It will finally return
the value found at token.default.backend. The method walks upwards untill
it either finds the expected key or it does not find another C<inherit>.
Note: As we can not distinguish an undef value from an unexisiting key, you
need to set the empty string to blank an entry.

=head3 configuration

  token:
    default:
      backend: OpenXPKI::Crypto::Backend::OpenSSL
      key: /etc/openxpki/ssl/default.pem


    ca-one-signer:
      inherit: default
      key: key: /etc/openxpki/ssl/mykey.pem


