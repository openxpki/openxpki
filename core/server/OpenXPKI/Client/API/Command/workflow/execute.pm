package OpenXPKI::Client::API::Command::workflow::execute;

use Moose;
extends 'OpenXPKI::Client::API::Command::workflow';

use MooseX::ClassAttribute;

use Data::Dumper;
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Field::Realm;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::execute;

=head1 SYNOPSIS

Run action on an existing workflow instance

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Int->new( name => 'id', label => 'Workflow Id', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'action', label => 'Action', hint => 'hint_action', required => 1 ),
    ]},
);

sub hint_action {

    my $self = shift;
    my $req = shift;

    my $actions = $self->api->run_command('get_workflow_activities', { id => $req->param('id') });
    $self->log->trace(Dumper $actions->result) if ($self->log->is_trace);
    return $actions->result || [];

}

sub execute {

    my $self = shift;
    my $req = shift;

    my $client;
    try {

        my $wf_parameters = {};
        if ($req->payload()) {
            $wf_parameters = $self->_build_hash_from_payload($req);
        }
        my $res = $self->api->run_command('execute_workflow_activity', {
                id => $req->param('id'),
                activity => $req->param('action'),
                params => $wf_parameters,
        });
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;
