package OpenXPKI::Client::API::Command::datapool::rename;


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

OpenXPKI::Client::API::Command::datapool::rename

=head1 SYNOPSIS

Change the key of an existing datapool value

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'namespace', label => 'Namespace', hint => 'hint_namespace', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'key', label => 'Key', hint => 'hint_key', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'newkey', label => 'New value of for key', required => 1 ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $res = $self->api->run_command('modify_data_pool_entry', {
        namespace => $req->param('namespace'),
        key =>  $req->param('key'),
        newkey => $req->param('newkey'),
    });
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;
