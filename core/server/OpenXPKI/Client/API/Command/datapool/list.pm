package OpenXPKI::Client::API::Command::datapool::list;

use Moose;
extends 'OpenXPKI::Client::API::Command::datapool';

use MooseX::ClassAttribute;

use Data::Dumper;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Field::Bool;


=head1 NAME

OpenXPKI::Client::API::Command::datapool::list

=head1 SYNOPSIS

List datapool keys/items for a given namespace

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'namespace', label => 'Namespace', hint => 'hint_namespace', required => 1 ),
        OpenXPKI::DTO::Field::Int->new( name => 'limit', label => 'Result Count', value => 25 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'metadata', label => 'Show Metadata' ),

    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my %query = (
        namespace => $req->param('namespace'),
    );
    $query{metadata} = 1 if ($req->param('metadata'));
    my $res = $self->api->run_command('list_data_pool_entries', \%query );
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;


