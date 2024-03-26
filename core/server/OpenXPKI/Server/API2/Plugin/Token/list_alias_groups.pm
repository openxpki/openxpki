package OpenXPKI::Server::API2::Plugin::Token::list_alias_groups;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::list_alias_groups

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Plugin::Token::Util;


=head1 COMMANDS

=head2 list_alias_groups

Returns an I<ArrayRef> with all alias group names in the given realm

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PK realm, specify this to query another realm.
Default: current session's realm.

=item * C<valid> I<Bool> - if set to true returns only groups having valid items

=back

=cut

command "list_alias_groups" => {
    pki_realm    => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm }, },
    valid   => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my %query;
    %query = (
        'notbefore' => { '<' => time() },
        'notafter'  => { '>' => time() },
    ) if ($params->valid);

    my $groups = CTX('dbi')->select_column(
        from => 'aliases',
        columns => ['group_id'],
        where => {
            'pki_realm' => $params->pki_realm,
            %query
        },
        group_by => 'group_id',
        order_by => [ 'group_id' ],
    );

    return $groups;
};


__PACKAGE__->meta->make_immutable;
