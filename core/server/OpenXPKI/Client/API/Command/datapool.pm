package OpenXPKI::Client::API::Command::datapool;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::CLI::Command::datapool

=head1 DESCRIPTION

Manage datapool items.

=cut

sub hint_namespace ($self, $input_params) {
    my $types = $self->run_command('list_data_pool_namespaces');
    return $types->result;
}

sub hint_key ($self, $input_params) {
    my $keys = $self->run_command('list_data_pool_entries', {
        namespace => $input_params->{namespace},
    });
    return [ map { $_->{key} } @{$keys->result} ];
}


1;
