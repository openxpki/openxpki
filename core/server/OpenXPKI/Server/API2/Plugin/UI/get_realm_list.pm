package OpenXPKI::Server::API2::Plugin::UI::get_realm_list;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_realm_list

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


=head1 COMMANDS

=head2 get_realm_list

Returns the realms of the PKI as list, each item is a hash with the items
I<name> and I<label>.

=cut
command "get_realm_list" => {
} => sub {
    my ($self, $params) = @_;

    my @realm_names = CTX('config')->get_keys(['system','realms']);
    my @realms;
    foreach my $realm (sort @realm_names) {
        my $label = CTX('config')->get(['system','realms', $realm, 'label']);
        push @realms, { name => $realm, label => $label };
    }

    return \@realms;
};

__PACKAGE__->meta->make_immutable;
