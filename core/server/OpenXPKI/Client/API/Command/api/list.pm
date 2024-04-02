package OpenXPKI::Client::API::Command::api::list;

use Moose;
extends 'OpenXPKI::Client::API::Command::api';

use MooseX::ClassAttribute;

use Data::Dumper;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::api::list

=head1 SYNOPSIS

Show the list of available commands

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    return OpenXPKI::Client::API::Response->new(
        payload => $self->list_command()
    );

}

__PACKAGE__->meta()->make_immutable();

1;
