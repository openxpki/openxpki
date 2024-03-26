package OpenXPKI::Client::API::Command::token::update;

use Moose;
extends 'OpenXPKI::Client::API::Command::token';
with 'OpenXPKI::Client::API::Command::NeedRealm';
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::Epoch;
use OpenXPKI::DTO::Field::Int;
use OpenXPKI::DTO::Field::File;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Message::Response;
use OpenXPKI::DTO::ValidationException;
use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::token::add

=head1 SYNOPSIS

Add a new generation of a crytographic token.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'alias', 'label' => 'Alias', hint => 'hint_type', required => 1 ),
        OpenXPKI::DTO::Field::File->new( name => 'key', label => 'Key file (new)' ),
        OpenXPKI::DTO::Field::File->new( name => 'key-update', label => 'Key file (update)' ),
        OpenXPKI::DTO::Field::Epoch->new( name => 'notbefore', label => 'Validity override (notbefore)' ),
        OpenXPKI::DTO::Field::Epoch->new( name => 'notafter', label => 'Validity override (notafter)' ),
    ]},
);

sub hint_type {
    my $self = shift;
    my $req = shift;
    my $groups = $self->api->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

sub execute {

    my $self = shift;
    my $req = shift;

    my $alias = $req->param('alias');
    my $param = { alias => $alias };

    foreach my $key ('notbefore','notafter') {
        $param->{$key} = $req->param($key) if (defined $req->param($key));
    }

    my $res;
    if ((scalar keys %$param) > 1) {
        $res = $self->api->run_protected_command('update_alias', $param );
        $self->log->debug("Alias $alias was updated");
    } else {
        $res = $self->api->run_command('show_alias', $param );
        die "Alias $alias not found" unless $res;
    }

    # update the key - the handle_key method will die if the alias is not a token
    if ($req->param('key')) {
        my $token = $self->handle_key($alias, $req->param('key'));
        $self->log->debug("Key for $alias was added");
        $res->params->{key_name} = $token->param('key_name');
    # set force for update mode (overwrites exising key)
    } elsif ($req->param('key-update')) {
        my $token = $self->handle_key($alias, $req->param('key-update'), 1);
        $self->log->debug("Key for $alias was updated");
        $res->params->{key_name} = $token->param('key_name');
    }

    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;
