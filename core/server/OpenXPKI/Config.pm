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
use Log::Log4perl;

# Make sure the underlying connector is recent
use Connector 1.08;

extends 'Connector::Multi';

has '+BASECONNECTOR' => (
    is => 'rw',
    isa => 'Connector',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->backend();
    },
);

has backend => (
    is => 'rw',
    isa => 'Connector',
    init_arg => 'backend',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Config::Backend->new(LOCATION => $self->config_dir);
    },
);

has credential_backend => (
    is => 'rw',
    isa => 'Bool',
    default => 0
    );

# Here we do the chain loading of a serialized/signed config
sub BUILD {
    my $self = shift;
    my $args = shift;

    # when we are here, the BASECONNECTOR is already initialized which is
    # usually an instance of O::C::Backend. We now probe if there is a
    # node called "bootstrap" and if so we replace the current backend
    if ($self->backend()->exists('bootstrap')) {

        # this is a connector definition
        my $bootstrap = $self->backend()->get_hash('bootstrap');

        my $class = $bootstrap->{class} || 'OpenXPKI::Config::Loader';
        if ($class !~ /\A(\w+\:\:)+\w+\z/) {
            die "Invalid class name $class";
        }
        ##! 16: 'Config bootstrap ' . Dumper $bootstrap
        eval "use $class;1;" or die "Unable to bootstrap config, can not use $class: $@";

        delete $bootstrap->{class};

        my $conn = $class->new( $bootstrap );
        $self->backend( $conn );
    }

    # If the node credential is defined on the top level we make assume
    # it contains a connector specification to create a globally available
    # node to receive passwords from
    if ($self->backend()->exists('credentials')) {
        my $conn = $self->backend();
        my $meta = $conn->get_meta('credentials');
        if ($meta->{TYPE} ne "hash" || !$conn->exists('credentials.class')) {
            warn "Found credential node but it does not look like a connector specification"
        } else {
            # There is a dragon inside! We read the connector details and
            # afterwards delete the node and write back the preinitialized
            # connector. This makes assumptions on the internal cache and might
            # also not work with other backend classes.
            $self->credential_backend(1);
            my $cc = $self->get_connector('credentials');
            $self->_init_cache();
            # as it is not allowed to change the type we need to unset it first
            $conn->set('credentials' => undef);
            # now we directly attach the connector to it
            $conn->set('credentials' => $cc);
            Log::Log4perl->get_logger('system')->info("Added credential connector");
        }
    }

    # check if the system node is present
    $self->backend()->exists('system') || die "Loaded config does not contain system node.";

}

has 'config_dir' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => '/etc/openxpki/config.d',
);

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
    if ( substr ($location, 0, 6) eq 'system' || substr($location, 0, 5) eq 'realm') {
        ##! 16: "_route_call: system or explicit realm value, reset connector offsets"
        $self->PREFIX('');
    } elsif (substr($location, 0, 11) eq "credentials" && $self->credential_backend()) {
        ##! 16: "_route_call: request for credential"
        $self->PREFIX('');
    } else {
        my $session = CTX('session');
        # there is no realm during init - hide tree by setting non existing prefix
        my $pki_realm = $session->data->pki_realm;
        if ($pki_realm) {
            ##! 16: "_route_call: realm value, set prefix to " . $pki_realm
            $self->PREFIX( [ 'realm', $pki_realm ] );
        } else {
            $self->PREFIX( "startup" );
        }
    }

    ##! 8: 'Full path: ' . Dumper $path
};

sub checksum {
    my $self = shift;
    $self->BASECONNECTOR()->_config(); # makes sure the backend is initialized
    return $self->BASECONNECTOR()->checksum();
}

sub get_version {
    my $self = shift;
    Log::Log4perl->get_logger('openxpki.deprecated')->error('Call to get_version in config layer');
    return '';
}

sub get_head_version {
    Log::Log4perl->get_logger('openxpki.deprecated')->error('Call to get_head_version in config layer');
}

sub update_head {
    my $self = shift;
    Log::Log4perl->get_logger('openxpki.deprecated')->error('Call to update_head in config layer');
    return '';
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
        CTX('log')->system()->error("get_scalar_as_list got invalid node type");

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

OpenXPKI::Config - Connector based configuration layer

=head1 SYNOPSIS

    use OpenXPKI::Config;

    my $cfg = OpenXPKI::Config->new(); # defaults to /etc/openxpki/config.d
    print "Param1=", $cfg->get('subsystem1.group1.param1'), "\n";

You can also specify a different directory holding the configuration:

    my $cfg = OpenXPKI::Config->new(config_dir => "/tmp/openxpki");

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

=head2 update_head, get_version, get_head_version

No longer supported

=head2 checksum

Print out the checksum of the current backend, might not be available
with all backends.

=head2 walkQueryPoints

Removed - use Connector::Tee instead

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

    $conn->get_inherit('token.ca-signer.backend')

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
      key: /etc/openxpki/ca/default.pem


    ca-signer:
      inherit: default
      key: key: /etc/openxpki/ca/mykey.pem


