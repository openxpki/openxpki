package OpenXPKI::Server::API2::Plugin::Token::get_token_alias_by_x;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::get_token_alias_by_x

=head1 COMMANDS

=cut

use Mojo::Loader;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Plugin::Token::Util;

=head2 get_token_alias_by_type

Returns the name of the "best" token for the given token type. For a definition
of "best" see API command L<get_token_alias_by_group|OpenXPKI::Server::API2::Plugin::Token::get_token_alias_by_group>

Looks up the token group for that type at config path I<realm.crypto.type>
and then calls L</get_token_alias_by_group>.

B<Parameters>

=over

=item * C<type> I<Str> - Token type (for possible values see L<OpenXPKI::Types/TokenType>). Required.

=item * C<validity> I<HashRef> - two datetime objects, given as hash keys
I<notbefore> and I<notafter>. Hash values of C<undef> will be interpreted as
"now". Default: now

=back

=cut
command "get_token_alias_by_type" => {
    type     => { isa => 'TokenType', required => 1, },
    validity => { isa => 'HashRef',   default => sub { { notbefore => undef, notafter => undef } }, },
} => sub {
    my ($self, $params) = @_;

    ##! 32: "Lookup group for type $params->type"
    my $group = CTX('config')->get("crypto.type.".$params->type)
        or OpenXPKI::Exception->throw (
            message => 'Could not find token group for given type',
            params => { type => $params->type }
        );

    return $self->_token_alias_by_group($group, $params->validity);
};

=head2 get_token_alias_by_group

Returns the name (alias) of the "best" token for the given token group.

By default, the "best" match is the newest token (i.e. token with the newest
I<notbefore> date) that is usable now. You can specify an alternative time frame
using the C<validity> parameter to find a token that is able to sign a request
with the given validity.

B<Parameters>

=over

=item * C<group> I<Str> - Token group. Required.

=item * C<validity> I<HashRef> - two datetime objects, given as hash keys
I<notbefore> and I<notafter>. Hash values of C<undef> will be interpreted as
"now". Default: now

=back

=cut
command "get_token_alias_by_group" => {
    group    => { isa => 'AlphaPunct', required => 1, },
    validity => { isa => 'HashRef',   default => sub { { notbefore => undef, notafter => undef } }, },
} => sub {
    my ($self, $params) = @_;

    return $self->_token_alias_by_group($params->group, $params->validity);
};


=head2 list_token_groups

Return the map to assign group names to the token types.

=cut
command "list_token_groups" => {
} => sub {
    my ($self, $params) = @_;
    return CTX('config')->get_hash('crypto.type');
};

#
# Look up token alias by group
#
sub _token_alias_by_group {
    my ($self, $group, $validity) = @_;

    # Support for "static" tokens (direct configuration without alias)
    # For the moment this is only the vault class so we hard code it
    # should be moved to a class property / role
    if (my $class = CTX('config')->get_inherit(["crypto","token",$group,"class"])) {
        if (my $err =Mojo::Loader::load_class($class)) {
            die "Unable to load implementation class for token group $group\n$err\n";
        }
        if ($class->DOES('OpenXPKI::Crypto::Token::Role::Static')) {
            ##! 16: "Looks like $group is static"
            return $group;
        }
    }

    my $pki_realm = CTX('session')->data->pki_realm;
    ##! 16: "Find token for group $params->group in realm $pki_realm"

    my $validity_epoch = OpenXPKI::Server::API2::Plugin::Token::Util->validity_to_epoch($validity);

    my $alias = CTX('dbi')->select_one(
        from => 'aliases',
        columns => [ 'alias' ],
        where => {
            pki_realm => $pki_realm,
            group_id  => $group,
            notbefore => { '<' => $validity_epoch->{notbefore} },
            notafter  => { '>' => $validity_epoch->{notafter} },
        },
        order_by => [ '-notbefore' ],
    )
    or OpenXPKI::Exception->throw (
        message => 'Could not find token alias by group',
        params => {
            group     => $group,
            notbefore => $validity_epoch->{notbefore},
            noafter   => $validity_epoch->{notafter},
            pki_realm => $pki_realm
        }
    );

    ##! 16: "Suggesting $alias->{'alias'} as best match"
    return $alias->{alias};
}


__PACKAGE__->meta->make_immutable;
