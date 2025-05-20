package OpenXPKI::Client::API::Command::acme::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::acme::list

=head1 DESCRIPTION

List all ACME account entries from the datapool.

Shows the datapool ID, the account KID and the key thumbprint.
To get account data and key information please use I<show>.

=cut

command "list" => {
} => sub ($self, $param) {

    my $res = $self->run_command('list_data_pool_entries', {
        namespace => 'nice.acme.account',
    });

    my @result;
    foreach my $account (@{$res->result}) {
        $res = $self->run_command('get_data_pool_entry', {
            namespace => 'nice.acme.account',
            key => $account->{key},
            deserialize => 'simple',
        })->params;
        push @result, {
            key_id => $account->{key},
            kid =>    $res->{value}->{kid},
            thumbprint => $res->{value}->{thumbprint},
        };
    }
    return \@result;
};

__PACKAGE__->meta->make_immutable;

