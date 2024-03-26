package OpenXPKI::Client::API::Command::token::list;

use Moose;
extends 'OpenXPKI::Client::API::Command::token';
with 'OpenXPKI::Client::API::Command::NeedRealm';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::token::status

=head1 SYNOPSIS

Show information about the active crypto tokens in a realm.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'type', 'label' => 'Token type (e.g. certsign)', hint => 'hint_type' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $groups = $self->api->run_command('list_token_groups');
    my $res = { token_types => $groups->params, token_groups => {} };

    my @names = values %{$groups->params};
    if ($req->param('type')) {
        @names = ( $groups->param($req->param('type')) );
    }

    foreach my $group (@names) {
        my $entries = $self->api->run_command('list_active_aliases', { group => $group });
        my $grp = {
            count => (scalar @{$entries->result}),
            active => $entries->result->[0]->{alias},
            token => [],
        };
        foreach my $entry (@{$entries->result}) {
            my $token = $self->api->run_command('get_token_info', { alias => $entry->{alias} });
            delete $token->params->{key_cert};
            push @{$grp->{token}}, $token->params;
        }
        $res->{token_groups}->{$group} = $grp;
    }
    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;
