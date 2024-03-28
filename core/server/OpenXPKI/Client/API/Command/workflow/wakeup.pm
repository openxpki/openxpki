package OpenXPKI::Client::API::Command::workflow::wakeup;

use Moose;
extends 'OpenXPKI::Client::API::Command::workflow';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Int;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::wakeup;

=head1 SYNOPSIS

Manually wakeup a paused workflow.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'async' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'wait' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $res = $self->api->run_command('wakeup_workflow', {
        id => $req->param('id'),
        async => $req->param('async') ? 1 : 0,
        wait => $req->param('wait') ? 1 : 0,
    });
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;

