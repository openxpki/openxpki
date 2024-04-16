package OpenXPKI::Client::API::Command::datapool;

use Moose;
extends 'OpenXPKI::Client::API::Command';
with 'OpenXPKI::Client::API::Command::NeedRealm';

# Core modules
use Data::Dumper;
use List::Util qw( none );

=head1 NAME

OpenXPKI::CLI::Command::datapool

=head1 SYNOPSIS

Manage datapool items

=head1 USAGE

Feed me!

=head2 Subcommands

=over

=item list

=item show

=item create

=item delete

=back

=cut

sub hint_namespace {
    my $self = shift;
    my $req = shift;

    my $types = $self->api->run_command('list_data_pool_namespaces');
    $self->log->trace(Dumper $types) if ($self->log->is_trace);
    return $types->result;

}

sub hint_key {
    my $self = shift;
    my $req = shift;

    my $keys = $self->api->run_command('list_data_pool_entries', {
        namespace => $req->param('namespace')
    });
    $self->log->trace(Dumper $keys) if ($self->log->is_trace);
    return [ map { $_->{key} } @{$keys->result} ];

}


__PACKAGE__->meta()->make_immutable();

1;
