package OpenXPKI::Server::API2::Plugin::UI::get_motd;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_motd

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;



=head1 COMMANDS

=head2 get_motd

Returns the message of the day (MOTD) from the datapool.

By default, the MOTD for the current users' role is returned. Another role
can be specified.

B<Parameters>

=over

=item * C<role> I<Str> - user role for which the motd shall be returned.

=back

=cut
command "get_motd" => {
    role => { isa => 'Value', },
} => sub {
    my ($self, $params) = @_;

    my $role = $params->has_role ? $params->role : CTX('session')->data->role;

    my $datapool;
    # role is used as Datapool key, fallback: query Datapool MOTD entry for "_any"
    for my $r ($role, '_any') {
        $datapool = $self->api->get_data_pool_entry(
            namespace => 'webui.motd',
            key => $r,
            deserialize => 'simple',
        );
        ##! 16: "Item for role '$r': " . Dumper $datapool
        last if $datapool;
    }

    return $datapool->{value};
};

__PACKAGE__->meta->make_immutable;
