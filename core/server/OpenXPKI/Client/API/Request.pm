package OpenXPKI::Client::API::Request;

use Moose;

=head1 NAME

OpenXPKI::Client::API::Request

=head1 SYNOPSIS

The request object used to pass the input data to the dispatcher.

=cut

=head1 Parameters

=head2 args

Holds any additional positional argument(s) passed in addition to the
command/subcommand.

=cut

has args => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub { return [] },
    predicate => 'has_args',
);

=head2 params

Holds any named parameters given to the command as a HashRef.

=cut

has params => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { return {} }
);

=head2 payload

Additional "payload" parameters that are not part of the commands
parameters.

=cut

# TODO - string type is not really useful for JSON based inputs
# but we might want to have some restrictions

has payload => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub { return [] },
    predicate => 'has_payload',
);

=head1 Methods

=head2 param I<name>

Helper to get the value of the named parameter from C<params>.

Returns the value "as is" or undef if the key is not found.

=cut

sub param {

    my $self = shift;
    my $name = shift;

    my $p = $self->params();

    return unless exists $p->{$name};

    return $p->{$name};

}

__PACKAGE__->meta()->make_immutable();

1;