package OpenXPKI::Client::API::Command::datapool::delete;


use Moose;
extends 'OpenXPKI::Client::API::Command::datapool';

use MooseX::ClassAttribute;

use Data::Dumper;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Epoch;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::delete

=head1 SYNOPSIS

Delete a single item or a full namespace from the datapool

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'namespace', label => 'Namespace', hint => 'hint_namespace', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'key', label => 'Key if the item to be removed', hint => 'hint_key',),
        OpenXPKI::DTO::Field::Bool->new( name => 'all', label => 'Remove the full namespace' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $res;
    if ($req->param('key')) {
        $res = $self->api->run_command('delete_data_pool_entry', {
            namespace => $req->param('namespace'),
            key =>  $req->param('key'),
        });
    } elsif ($req->param('all')) {
        $res = $self->api->run_command('clear_data_pool_namespace', {
            namespace => $req->param('namespace'),
        });
    } else {
        die "You must pass either a key to be deleted or the --all flag"
    }
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;
