package OpenXPKI::Base::API::Autoloader;
use OpenXPKI -class;

# Core modules
use List::Util qw( any );

=head1 NAME

OpenXPKI::Base::API::Autoloader - Thin wrapper around the API that virtually
provides all API commands as instance methods

=head2 DESCRIPTION

B<Not intended for direct use> - this is part of the internal API magic.

=cut

has api => (
    is => 'ro',
    does => 'OpenXPKI::Base::API::APIRole',
    required => 1,
);

# only for "command" mode
has namespace => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_namespace',
);

# cache Autoloader objects for each namespace
my $namespace_loaders = {};

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
        $namespace_loaders->{$method} = __PACKAGE__->new(api => $self->api, mode => 'command', namespace => $method)
            unless $namespace_loaders->{$method};
        return $namespace_loaders->{$method};

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
