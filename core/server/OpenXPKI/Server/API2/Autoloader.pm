package OpenXPKI::Server::API2::Autoloader;
use OpenXPKI -class;

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

sub AUTOLOAD ($self, @args) {
    our $AUTOLOAD; # $AUTOLOAD is a magic variable containing the full name of the requested sub
    my $command = $AUTOLOAD;
    $command =~ s/.*:://;
    return if $command eq "DESTROY";

    if (scalar @args > 0 and ref $args[0]) {
        OpenXPKI::Exception->throw(
            message => "Wrong usage of API command. Expected parameters as plain hash, got: reference",
            params => { command => $command },
        );
    }
    if (scalar @args % 2 == 1) {
        OpenXPKI::Exception->throw(
            message => "Odd number of parameters given to API command. Expected: plain hash",
            params => { command => $command },
        );
    }
    $self->api->dispatch(
        command => $command,
        params => { @args },
    );
}

__PACKAGE__->meta->make_immutable;
