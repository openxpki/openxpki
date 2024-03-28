package OpenXPKI::Client::API::Command::workflow::archive;

use Moose;
extends 'OpenXPKI::Client::API::Command::workflow';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Int;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::archive

=head1 SYNOPSIS

Trigger archivial of a workflow.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;
    my $res = $self->api->run_command('archive_workflow', {
        id => $req->param('id'),
    });
    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;
