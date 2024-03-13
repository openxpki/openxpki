package OpenXPKI::Client::API::Command::workflow::list;

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
use OpenXPKI::DTO::ValidationException;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::list

=head1 SYNOPSIS

List workflow ids based on given filter criteria.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Realm->new(),
        OpenXPKI::DTO::Field::String->new( name => 'state', label => 'Workflow State' ),
        OpenXPKI::DTO::Field::String->new( name => 'proc_state', label => 'Workflow Proc State', hint => 'hint_proc_state' ),
        OpenXPKI::DTO::Field::String->new( name => 'type', label => 'Workflow Type', hint => 'hint_type' ),
        OpenXPKI::DTO::Field::Int->new( name => 'limit', label => 'Result Count', value => 25 ),
    ]},
);

sub hint_type {
    my $self = shift;
    my $req = shift;
    my $input = shift;

    my $client = $self->client($req->param('realm'));
    my $types = $client->run_command('get_workflow_instance_types');
    TRACE(Dumper $types);
    return [ map { sprintf '%s (%s)', $_, $types->{$_}->{label} } sort keys %$types ];

}

sub hint_proc_state {
    my $class = shift;
    my $req = shift;
    my $input = shift;
    return ['running','manual','finished','pause','exception','retry_exceeded','archived','failed'];
}

sub execute {

    my $self = shift;
    my $req = shift;

    my %query = map {
        my $val = $req->param($_);
        (defined $val) ? ($_ => $val) : ()
    } ('type','proc_state','state','limit');

    my $client;
    try {
        $client = $self->client($req->param('realm'));
        my $res = $client->run_command('search_workflow_instances', \%query );
        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;


