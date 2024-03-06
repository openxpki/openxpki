package OpenXPKI::Client::API::Command::acme::show;

use Moose;
extends 'OpenXPKI::Client::API::Command::acme';
with 'OpenXPKI::Role::ACME';

use MooseX::ClassAttribute;

use JSON::PP qw(decode_json);
use Data::Dumper;
use Feature::Compat::Try;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Field::Realm;

=head1 NAME

OpenXPKI::Client::API::Command::acme::show

=head1 SYNOPSIS

Show an account entry from the datapool.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Realm->new( required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'id', label => 'Account Key Id', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'with-privatekey', label => 'Show Private Key'),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $client;
    try {
        $client = $self->client($req->param('realm'));

        my $res = $client->run_command('get_data_pool_entry', {
            namespace => 'nice.acme.account',
            key => $req->param('id'),
            deserialize => 'simple',
        });

        my $out = $res->{value};
        $out->{key_id} = $req->param('id');
        delete $out->{jwk} unless($req->param('with-privatekey'));
        return OpenXPKI::Client::API::Response->new( payload => $out );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;

