package OpenXPKI::Server::Authentication::Base;

use strict;
use warnings;

use Moose;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

## constructor and destructor stuff

has role => (
    is => 'ro',
    isa => 'Str|Undef',
    predicate => 'has_role',
);

has prefix => (
    is => 'ro',
    isa => 'ArrayRef',
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
    return $class->$orig(%{$args});
};

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

