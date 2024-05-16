package OpenXPKI::Server::API2::Autoloader;
use OpenXPKI -class;

# Core modules
use List::Util qw( any );

# Project modules
use OpenXPKI::Server::API2;

=head1 NAME

OpenXPKI::Server::API2::Autoloader - Thin wrapper around the API that virtually
provides all API commands as instance methods

=head2 DESCRIPTION

B<Not intended for direct use.> Please use L<OpenXPKI::Server::API2/autoloader>
instead.

=cut

has api => (
    is => 'ro',
    isa => 'OpenXPKI::Server::API2',
    required => 1,
);

# only for "command" mode
has namespace => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_namespace',
);

sub AUTOLOAD ($self, @args) {
    our $AUTOLOAD; # $AUTOLOAD is a magic variable containing the full name of the requested sub
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq "DESTROY";

    # set namespace if
    if ($self->api->has_non_root_namespaces                      # there are namespaces
        and not $self->has_namespace                             # and it's not yet set (in the command chain)
        and any { $_ eq $method } $self->api->rel_namespaces->@* # and it's a known namespace
    ) {
        return __PACKAGE__->new(api => $self->api, mode => 'command', namespace => $method);

    # call command
    } else {
        if (scalar @args > 0 and ref $args[0]) {
            OpenXPKI::Exception->throw(
                message => "Wrong usage of API command. Expected parameters as plain hash, got: reference",
                params => { command => $method },
            );
        }
        if (scalar @args % 2 == 1) {
            OpenXPKI::Exception->throw(
                message => "Odd number of parameters given to API command. Expected: plain hash",
                params => { command => $method },
            );
        }
        return $self->api->dispatch(
            $self->has_namespace ? (rel_namespace => $self->namespace) : (),
            command => $method,
            params => { @args },
        );
    }
}

__PACKAGE__->meta->make_immutable;
