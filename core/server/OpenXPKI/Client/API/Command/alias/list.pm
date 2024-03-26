package OpenXPKI::Client::API::Command::alias::list;

use Moose;
extends 'OpenXPKI::Client::API::Command::alias';
with 'OpenXPKI::Client::API::Command::NeedRealm';

use MooseX::ClassAttribute;

use List::Util 'any';

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::alias::list

=head1 SYNOPSIS

List (non-token) alias entries

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'group', 'label' => 'Token group (e.g. tg_server)', hint => 'hint_group' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'expired' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'valid' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'upcoming' ),
    ]},
);

sub hint_group {

    my $self = shift;
    my $aliases = $self->api->run_command('list_alias_groups');
    my $tokens = $self->api->run_command('list_token_groups');

    my @groups;
    while (my $item = shift @{$aliases->param('result')}) {
        push @groups, $item unless (any { $item eq $_ } values %{$tokens->params});
    }
    return  \@groups;
}

sub execute {

    my $self = shift;
    my $req = shift;

    my $groups = $self->hint_group();
    my $res = {};

    my %validity;
    foreach my $key ('expired','valid','upcoming') {
        $validity{$key} = 1 if ($req->param($key));
    }

    foreach my $group (@$groups) {
        my $entries = $self->api->run_command('list_aliases', { group => $group, %validity } );
        $res->{$group} = {
            count => (scalar @{$entries->result}),
            item => $entries->result,
        };
    }
    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;
