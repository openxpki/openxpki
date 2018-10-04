package OpenXPKI::Server::API2::Plugin::UI::get_motd;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_motd

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_motd

Returns the message of the day (MOTD, from the datapool).

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

    # role is used as DP Key, can also be "_any"
    my $datapool = CTX('api')->get_data_pool_entry({
        NAMESPACE => 'webui.motd',
        KEY       => $role,
    });
    ##! 16: 'Item for role ' . $role .': ' . Dumper $datapool

    # nothing found for given role, so try _any
    if (not $datapool) {
        $datapool = CTX('api')->get_data_pool_entry({
            NAMESPACE => 'webui.motd',
            KEY       => '_any'
        });
        ##! 16: 'Item for _any: ' . Dumper $datapool
    }

    return unless $datapool;

    return OpenXPKI::Serialization::Simple->new->deserialize($datapool->{VALUE});
};

__PACKAGE__->meta->make_immutable;
