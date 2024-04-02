package OpenXPKI::Client::API::Command::api::execute;

use Moose;
extends 'OpenXPKI::Client::API::Command::api';
with 'OpenXPKI::Client::API::Command::NeedRealm';


use MooseX::ClassAttribute;

use Data::Dumper;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::api::execute;

=head1 SYNOPSIS

Run a bare API command on the server

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'command', label => 'Command', hint => 'hint_command', required => 1 ),
    ]},
);

sub hint_command {

    my $self = shift;
    my $req = shift;

    my $actions = $self->api->run_enquiry('command');
    $self->log->trace(Dumper $actions->result) if ($self->log->is_trace);
    return $actions->result || [];

}

sub execute {

    my $self = shift;
    my $req = shift;

    my $command = $req->param('command');

    my $payload = {};
    if ($req->payload()) {
        $payload = $self->_build_hash_from_payload($req);
    }

    my $api_params = $self->help_command($command);
    my $cmd_parameters;
    foreach my $key (keys %$api_params) {
        $self->log->debug("Checking $key");
        if (defined $payload->{$key}) {
            $cmd_parameters->{$key} = $payload->{$key};
            delete $payload->{$key};
        } elsif ($api_params->{$key}->{required}) {
            die "The parameter $key is mandatory for running $command";
        }
    }

    if (my @keys = keys %$payload) {
        die "One or more arguments are not accepted by the API command: " . join(',', @keys);
    }

    my $res = $self->execute_command($req->param('command'), $cmd_parameters);
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;
