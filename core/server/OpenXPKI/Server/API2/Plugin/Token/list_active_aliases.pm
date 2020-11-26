package OpenXPKI::Server::API2::Plugin::Token::list_active_aliases;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::list_active_aliases

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Plugin::Token::Util;



=head1 COMMANDS

=head2 list_active_aliases

Returns an I<ArrayRef> of I<HashRefs> with all tokens from the given group,
which are/were valid within the given validity period:

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

The list is sorted by I<notbefore> date, starting with the newest date.

B<Parameters>

=over

=item * C<group> I<Str> - Token group. Default: none

=item * C<type> I<Str> - Token type, might be specified instead of token group
to query one of the predefined token types (for possible values see
L<OpenXPKI::Server::API2::Types/TokenType>). Default: none

=item * C<pki_realm> I<Str> - PK realm, specify this to query another realm.
Default: current session's realm.

=item * C<validity> I<HashRef> - two datetime objects, given as hash keys
I<notbefore> and I<notafter>. Hash values of C<undef> will be interpreted as
"now". Default: current time


=item * C<check_online> I<Bool> - Set to 1 to get the token online status
(L<is_token_usable|OpenXPKI::Server::API2::Plugin::Token::is_token_usable/is_token_usable> is
called for each alias). The status check is only possible from within the
current session's realm, for requests regarding another realm the status is
always C<UNKNOWN>. Default: 0

=back

=cut
command "list_active_aliases" => {
    group        => { isa => 'AlphaPunct', },
    type         => { isa => 'TokenType', },
    pki_realm    => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm }, },
    validity     => { isa => 'HashRef',    default => sub { { notbefore => undef, notafter => undef } }, },
    check_online => { isa => 'Bool',       default => 0 },
} => sub {
    my ($self, $params) = @_;

    my $group; $group = $params->group if $params->has_group;
    my $pki_realm = $params->pki_realm;

    if (not $params->has_group) {
        OpenXPKI::Exception->throw( message => "Token type or group must be given" ) unless $params->has_type;

        $group = CTX('config')->get("realm.$pki_realm.crypto.type.".$params->type)
            or OpenXPKI::Exception->throw(
                message => "Could not find token group by type",
                params => { type => $params->type },
            );
    }

    my $validity = OpenXPKI::Server::API2::Plugin::Token::Util->validity_to_epoch($params->validity);

    my $aliases = CTX('dbi')->select(
        from => 'aliases',
        columns => [
            'aliases.notbefore',
            'aliases.notafter',
            'aliases.alias',
            'aliases.identifier',
        ],
        where => {
            'aliases.pki_realm' => $pki_realm,
            'aliases.group_id'  => $group,
            'aliases.notbefore' => { '<' => $validity->{notbefore} },
            'aliases.notafter'  => { '>' => $validity->{notafter} },
        },
        order_by => [ '-aliases.notbefore' ],
    );

    my @result;
    while (my $row = $aliases->fetchrow_hashref) {
        my $item = {
            alias => $row->{alias},
            identifier => $row->{identifier},
            notbefore => $row->{notbefore},
            notafter  => $row->{notafter},
        };
        # security check: only do online/offline check if we check the session PKI realm
        if ($params->check_online) {
            if ($params->pki_realm eq CTX('session')->data->pki_realm) {
                $item->{status} = $self->api->is_token_usable(alias => $row->{alias})
                    ? 'ONLINE'
                    : 'OFFLINE';
            }
            else {
                $item->{status} = 'UNKNOWN';
                CTX('log')->application->warn("API command 'list_active_aliases' was called to query another realm's tokens with 'check_online = 1'. This is forbidden, 'status' will be set to UNKNOWN.");
            }
        }
        push @result, $item;
    }

    return \@result;
};

__PACKAGE__->meta->make_immutable;
