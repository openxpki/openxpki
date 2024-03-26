package OpenXPKI::Client::API::Command::alias::update;

use Moose;
extends 'OpenXPKI::Client::API::Command::alias';
with 'OpenXPKI::Client::API::Command::NeedRealm';
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Epoch;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::alias::update

=head1 SYNOPSIS

Update an existing alias entry

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'alias', 'label' => 'Alias', hint => 'hint_type', required => 1 ),
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

    die "At least one update parameter is mandatory" unless (scalar keys %$param);

    my $res = $self->api->run_protected_command('update_alias', $param );
    $self->log->debug("Alias $alias was updated");
    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;
