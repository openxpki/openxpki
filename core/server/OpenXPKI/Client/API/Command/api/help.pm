package OpenXPKI::Client::API::Command::api::help;

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

OpenXPKI::Client::API::Command::api::help;

=head1 SYNOPSIS

Show the argument list for the given command.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'command', label => 'Command', hint => 'list_command', required => 1 ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    return OpenXPKI::Client::API::Response->new(
        payload => $self->help_command( $req->param('command') )
    );

}

__PACKAGE__->meta()->make_immutable();

1;
