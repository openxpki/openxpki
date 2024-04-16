package OpenXPKI::Client::API::Command::datapool::update;


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

OpenXPKI::Client::API::Command::datapool::update;

=head1 SYNOPSIS

Update the value and/or expiration date of a datapool item

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'namespace', label => 'Namespace', hint => 'hint_namespace', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'key', label => 'Key', hint => 'hint_key', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'value', label => 'Value' ),
        OpenXPKI::DTO::Field::Epoch->new( name => 'expiry', label => 'Expiry Date' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $res;
    if ($req->param('value')) {
        # get the old value to copy over expiry and encryption
        my $old = $self->api->run_command('get_data_pool_entry', {
            namespace => $req->param('namespace'),
            key =>  $req->param('key'),
        });

        my $expiration = $req->param('expiry') // $old->param('expiration_date');
        my $encrypt = $old->param('encrypt') // 0;

        $self->api->run_command('set_data_pool_entry', {
            namespace => $req->param('namespace'),
            key =>  $req->param('key'),
            value => $req->param('value'),
            ($expiration ? (expiration_date => $expiration) : ()),
            encrypt => $encrypt,
            force => 1,
        });

        $res = $self->api->run_command('get_data_pool_entry', {
            namespace => $req->param('namespace'),
            key =>  $req->param('key'),
        });

    } elsif ($req->param('expiry')) {
        $res = $self->api->run_command('modify_data_pool_entry', {
            namespace => $req->param('namespace'),
            key =>  $req->param('key'),
            expiration_date => $req->param('expiry'),
        });
    } else {
        die "You must provide at least one of value or expiry date to update";
    }
    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;
