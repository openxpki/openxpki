package OpenXPKI::Server::API2::Plugin::Token::list_aliases;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::list_aliases

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;

=head1 COMMANDS

=head2 list_aliases

Returns an I<ArrayRef> of I<HashRefs> of all alias items matching the
given validity criteria. By default all items of the given group are
returned.

    [
        {
            alias => '...',      # full alias name
            identifier => '...', # certificate identifier
            notbefore => '...',  # certificate validity (UNIX epoch timestamp)
            notafter => '...',   # certificate validity (UNIX epoch timestamp)
            status => '...',     # verbose status of the token: ONLINE, OFFLINE or UNKNOWN
        },
        {
            ...
        },
    ]

Dates are taken from the alias table and might differ from the certificates
validity!

The list is sorted by by I<notbefore> date, starting with the newest date.

B<Parameters>

=over

=item * C<group> I<ArrayRef|Str> - Token group, mandatory

=item * C<global> I<Bool> - weather to show the global alias table

=item * C<valid> I<Bool> - weather to show only valid items (default is no)

=item * C<expired> I<Bool> - weather to show only expired items (default is no)

=item * C<upcoming> I<Bool> - weather to show only upcoming items (default is no)

=back

=cut
command "list_aliases" => {
    group   => { isa => 'AlphaPunct', required => 1 },
    global  => { isa => 'Bool', default => 0 },
    valid   => { isa => 'Bool', default => 0 },
    expired   => { isa => 'Bool', default => 0 },
    upcoming   => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my $pki_realm = $params->global ? '_global' : CTX('session')->data->pki_realm;

    my %query;
    %query = (
        'notbefore' => { '<' => time() },
        'notafter'  => { '>' => time() },
    ) if ($params->valid);

    if ($params->expired) {
        if ($params->valid) {
            delete $query{notafter}
        } else {
            $query{notafter} = { '<', time };
        }
    }

    if ($params->upcoming) {
        if ($params->valid) {
            delete $query{notbefore};
        } else {
            $query{notbefore} = { '>', time };
        }
    }

    my $aliases = CTX('dbi')->select_hashes(
        from => 'aliases',
        columns => [
            'notbefore',
            'notafter',
            'alias',
            'identifier',
        ],
        where => {
            'pki_realm' => $pki_realm,
            'group_id' => $params->group,
            %query
        },
        order_by => [ '-notbefore' ],
    );

    return $aliases || {};
};

__PACKAGE__->meta->make_immutable;

