package OpenXPKI::Client::API::Command::datapool::add;


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

OpenXPKI::Client::API::Command::datapool::add;

=head1 SYNOPSIS

Add a new value to the datapool

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'namespace', label => 'Namespace', hint => 'hint_namespace', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'key', label => 'Key', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'value', label => 'Value', required => 1 ),
        OpenXPKI::DTO::Field::Epoch->new( name => 'expiry', label => 'Expiry Date' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'encrypt', label => 'Encrypt' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $res = $self->api->run_command('set_data_pool_entry', {
        namespace => $req->param('namespace'),
        key =>  $req->param('key'),
        value => $req->param('value'),
        ($req->param('expiry') ? (expiration_date => $req->param('expiry')) : ()),
        ($req->param('encrypt') ? (encrypt => 1) : ()),
    });
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;
