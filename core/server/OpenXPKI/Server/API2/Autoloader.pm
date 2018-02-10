package OpenXPKI::Server::API2::Autoloader;
use strict;
use warnings;
use utf8;

=head1 NAME

OpenXPKI::Server::API2::Autoloader - Thin wrapper around the API that virtually
provides all API commands as instance methods

=head2 DESCRIPTION

B<Not intended for direct use.> Please use L<OpenXPKI::Server::API2/autoloader>
instead.

=cut

# Project modules
use OpenXPKI::Exception;


sub new {
    my $class = shift;
    my %args = @_;

    OpenXPKI::Exception->throw(__PACKAGE__."->new() is a constructor, not an instance method")
        if ref $class;

    OpenXPKI::Exception->throw("Error in call to ".__PACKAGE__."->new(): parameter 'api' missing or not of type OpenXPKI::Server::API2")
        unless ($args{api} and ref $args{api} and $args{api}->isa("OpenXPKI::Server::API2"));

    return bless { %args }, $class;
}

sub AUTOLOAD {
    my ($self, @args) = @_;

    our $AUTOLOAD; # $AUTOLOAD is a magic var containing the full name of the requested sub
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
    $self->{api}->dispatch(
        command => $command,
        params => { @args },
    );
}

1;
