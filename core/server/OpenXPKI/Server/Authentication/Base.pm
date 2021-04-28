package OpenXPKI::Server::Authentication::Base;

use strict;
use warnings;
use Moose;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

has role => (
    is => 'ro',
    isa => 'Str|Undef',
    predicate => 'has_role',
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

sub get_userinfo {

    my $self = shift;
    my $username = shift;
    my $userinfo = CTX('config')->get_hash( [ @{$self->prefix()}, 'user', $username ] );
    return $userinfo || {};

}

sub map_role {

    my $self = shift;
    my $role = shift || '';

    # no role map defined, do nothing
    return $role unless ($self->has_rolemap);

    my $rolemap = $self->rolemap;

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

=head3 map_role

Check if the given string is a valid key in I<rolemap> and return its
value.

You can define the special key I<_default> to use as a fallback in case
the string is not found. If neither one matches, undef is returned.

If I<rolemap> is not set, returns the input string.
