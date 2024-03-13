package OpenXPKI::Client::API::Command::workflow::create;


use Moose;
extends 'OpenXPKI::Client::API::Command::workflow';

use MooseX::ClassAttribute;

use Data::Dumper;
use Feature::Compat::Try;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Field::Realm;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::create;

=head1 SYNOPSIS

Initiate a new workflow

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Realm->new( required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'type', label => 'Workflow Type', hint => 'hint_type', required => 1 ),

    ]},
);

sub hint_type {

    my $self = shift;
    my $req = shift;
    my $input = shift;

    # TODO - we need a new API method to get ALL types and not only the used ones!
    my $client = $self->client($req->param('realm'));
    my $types = $client->run_command('get_workflow_instance_types');
    $self->log()->trace(Dumper $types) if ($self->log()->is_trace);
    return [ map { sprintf '%s (%s)', $_, $types->{$_}->{label} } sort keys %$types ];

}

sub execute {

    my $self = shift;
    my $req = shift;

    my $client;
    try {
        $client = $self->client($req->param('realm'));
        my $wf_parameters = {};
        if ($req->payload()) {
            $wf_parameters = $self->_build_parameters_from_request($req);
        }
        my $res = $client->run_command('create_workflow_instance', {
            workflow => $req->param('type'),
            params => $wf_parameters,
        });
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;
