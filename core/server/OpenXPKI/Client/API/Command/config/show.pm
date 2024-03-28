package OpenXPKI::Client::API::Command::config::show;

use Moose;
extends 'OpenXPKI::Client::API::Command::config';
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::config::show;

=head1 SYNOPSIS

Show information of the (running) OpenXPKI configuration

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'path', label => 'Path to dump' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;
    my $params;
    if (my $path = $req->param('path')) {
        $params->{path} = $path;
    }
    my $res = $self->api->run_protected_command('config_show', $params);
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;


