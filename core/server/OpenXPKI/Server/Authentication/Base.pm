package OpenXPKI::Server::Authentication::Base;

use strict;
use warnings;
use Moose;

use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

has role => (
    is => 'ro',
    isa => 'Str|Undef',
    predicate => 'has_role',
);

has namespace => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_namespace',
);

has rolemap => (
    is => 'ro',
    isa => 'HashRef',
    predicate => 'has_rolemap',
);

has prefix => (
    is => 'ro',
    isa => 'ArrayRef',
);

has authinfo => (
    is => 'ro',
    isa => 'HashRef',
    predicate => 'has_authinfo',
    default => sub { return {} },
);

has logger => (
    lazy => 1,
    is => 'rw',
    isa => 'Object',
    default => sub { return CTX('log')->auth(); }
);


around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;

    my $prefix = shift;
    my @path = (ref $prefix) ? @{$prefix} : (split /\./, $prefix);

    my $config = CTX('config');
    my $args = { prefix => \@path };
    for my $attr ( $class->meta->get_all_attributes ) {
        my $attrname = $attr->name();
        next if $attrname =~ m/^_/; # skip apparently internal params
        my $meta = $config->get_meta( [ @path , $attrname ] );
        next unless($meta && $meta->{TYPE});
        if ($meta->{TYPE} eq 'scalar') {
            $args->{$attrname} = $config->get( [ @path , $attrname ] );
        } elsif ($meta->{TYPE} eq 'list') {
            my @tmp = $config->get_scalar_as_list( [ @path , $attrname ] );
            $args->{$attrname} = \@tmp;
        } elsif ($meta->{TYPE} eq 'hash') {
            $args->{$attrname} = $config->get_hash( [ @path , $attrname ] );
        }
    }
    ##! 32: 'Bootstrap handler '.$path[-1]
    ##! 64: $args

    return $class->$orig(%{$args});

};

sub get_userid {

    my $self = shift;
    my $username = shift;
    return $username unless($self->has_namespace());

    return sprintf("%s:%s", $self->namespace(),$username);
}

sub get_userinfo {

    ##! 1: 'start'
    my $self = shift;
    my $username = shift;
    ##! 16: $username
    my $userinfo = CTX('config')->get_hash( [ @{$self->prefix()}, 'user', $username ] ) || {};
    ##! 64: $userinfo
    $self->logger->trace("Userinfo for $username is " . Dumper $userinfo) if ($self->logger->is_trace);
    return $userinfo;

}

sub map_role {

    my $self = shift;
    my $role = shift || '';

    ##! 16: 'map role ' . $role
    # no role map defined, do nothing
    return $role unless ($self->has_rolemap);

    my $rolemap = $self->rolemap;

    ##! 128: $rolemap
    # role contained in map
    return $rolemap->{$role} if ($rolemap->{$role});

    $self->logger->debug("Role $role not found in map, check for _default");

    # the asterisk marks a default role
    return $rolemap->{'_default'} if ($rolemap->{'_default'});

    $self->logger->info("Unknown role $role was given");

    # no luck this time
    return ;

}


 1;

 __END__;

=head1 OpenXPKI::Server::Authentication::Base

The base class for all authentication handlers.

Expects the configuration path to the handlers parameters as argument
and stores it in the I<prefix> attribute.

Loads all config settings for attributes that exist in the configuration.

It also provides the I<role> attribute to all child classes.

=head2 Parameters

=over

=item prefix

The configuration path as passed to the constructor. Stored as ArrayRef,
if a string was passed it was split at the delimiter character.

=item role

Should receive a role preset, type is String/Undef.

=item authinfo

HashRef that might be added or preset to the returned handle.
See the handler subclass for details.

=item namespace

String to be used as namespace prefix when generating the userid. Should
be three to eight lowercase characters, the values I<certid>, I<system>
and I<internal> are reserved and must only be used if the handler returns
an adequate userid.

=back

=head2 Implementations

Handlers must implement the method I<handleInput> that is called with the
hash received from the authenticating client. They should return undef
if the data that was received is not sufficient to start authentication.

They must return an instance of OpenXPKI::Server::Authentication::Handle
in case an authentication attempt was made. On success, the attributes
I<username>, I<userid> and I<role> must be set. On error the I<error>
attribute must be set. See OpenXPKI::Server::Authentication::Handle for
more details / options.

=head2 Methods

=head3 get_userinfo

Expects the username as parameter and queries the configuration layer
at I<prefix>.user.I<username> for the userinfo hash. Returns an empty
hash if no userinfo was found.

Implementations should use this to allow an easy expansion of this
functionality

=head3 get_userid

While the username is related to the credentials that where used to
authentuicate the userid should provide a unique and durable handle
to link items to an identity. In case you have multiple authentication
backends the userid should be prefixed by a namespace - this method is
a simpe wrapper that expects the username and returns it prefixed with
the namespace set as parameter to this class. If namespace is not set,
it returns the unmodified input value.

=head3 map_role

Check if the given string is a valid key in I<rolemap> and return its
value.

You can define the special key I<_default> to use as a fallback in case
the string is not found. If neither one matches, undef is returned.

If I<rolemap> is not set, returns the input string.
