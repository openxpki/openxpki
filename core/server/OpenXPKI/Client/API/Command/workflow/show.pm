package OpenXPKI::Client::API::Command::workflow::show;

use Moose;
extends 'OpenXPKI::Client::API::Command::workflow';

use MooseX::ClassAttribute;

use Data::Dumper;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Int;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::show;

=head1 SYNOPSIS

Show information on an existing workflow

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'attributes', label => 'Show Attributes' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'deserialize', label => 'Deserialize Context', description => 'Unpack serialized context items' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my %param;
    if ($req->param('attributes')) {
        $param{'with_attributes'} = 1;
    }
    $self->log->trace(Dumper \%param) if ($self->log->is_trace);
    my $res = $self->api->run_command('get_workflow_info', { id => $req->param('id'), %param });
    if ($req->param('deserialize')) {
       $self->deserialize_context($res);
    }
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;


