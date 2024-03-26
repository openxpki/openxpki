package OpenXPKI::Client::API::Command::token::delete;

use Moose;
extends 'OpenXPKI::Client::API::Command::token';
with 'OpenXPKI::Client::API::Command::NeedRealm';
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::token::delete

=head1 SYNOPSIS

Delete the token for a given alias name

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'alias', 'label' => 'Alias', required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'remove-key', 'label' => 'Remove the key' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $alias = $req->param('alias');
    my $param = { alias => $alias };

    my $res = $self->api->run_command('show_alias', $param );
    die "Alias '$alias not' found" unless $res->param('alias');

    if ($req->param('remove-key')) {
        my $token = $self->api->run_command('get_token_info', $param );
        if ($token->param('key_store') ne 'DATAPOOL') {
            die "Unable to remove key as key is not stored in datapool";
        }
        $self->api->run_command('delete_data_pool_entry', {
            namespace => 'sys.crypto.keys',
            key => $token->param('key_name'),
        });
    }

    $res = $self->api->run_protected_command('delete_alias', $param );

    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;
