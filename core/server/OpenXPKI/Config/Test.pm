# OpenXPKI::Config
#
# Written 2012 by Oliver Welter for the OpenXPKI project
# Copyright (C) 2012 by The OpenXPKI Project
#

package OpenXPKI::Config::Test;

use strict;
use warnings;
use English;
use Moose;
use Connector::Proxy::Config::Versioned;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

extends 'Connector::Multi';

has '+BASECONNECTOR' => ( required => 0 );

has '_head_version' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
);


around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    my $dbpath = $ENV{OPENXPKI_CONF_DB} || 't/config.git/';

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
    ##! 16: "Init config system - head version " . $cv->version()
    return $class->$orig( { BASECONNECTOR => $cv, _head_version => $cv->version() } );
};

before '_route_call' => sub {

    my $self = shift;
    my $call = shift;
    my $location = shift;

    ##! 16: "_route_call interception on $location "
    # system is global and never has a prefix or version
    if ( substr ($location, 0, 6) eq 'system' ) {
        $self->_config()->{''}->PREFIX('');
    } else {
        $self->_config()->{''}->PREFIX( "realm.I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA" );
    }
};

sub get_version {
    my $self = shift;
    ##! 16: 'Config version requested ' . Dumper( $self->BASECONNECTOR()->version() )
    return $self->BASECONNECTOR()->version();
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
    foreach my $resolver (  $self->get_list( "$prefix.resolvers" ) ) {
        ##! 32: 'Ask Resolver ' . $prefix.'.'.$resolver.'.'.$query
        $result = $self->$call( "$prefix.$resolver.$query" , $params );
        return { 'VALUE' => $result, 'SOURCE' => $resolver } if ($result);
    }
    return;
}

sub get_scalar_as_list {
    my $self = shift;
    my $path = shift;
    my @values;
    my $meta = $self->get_meta( $path );
    if ($meta && $meta->{TYPE} eq 'list') {
        @values = $self->get_list( $path );
    } else {
        @values = ( $self->get( $path ) );
    }
    return @values;
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

