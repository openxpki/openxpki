package OpenXPKI::Server::API2::Plugin::Token::get_ca_list;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::get_ca_list

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Plugin::Token::Util;

# CPAN modules
use Feature::Compat::Try;


=head2 get_ca_list

List all items in the I<certsign> group of the requested realm.

Each entry of the list is a I<HashRef>:

    {
        alias => '...',      # full alias name
        identifier => '...', # certificate identifier
        notbefore => '...',  # certificate validity (UNIX epoch timestamp)
        notafter => '...',   # certificate validity (UNIX epoch timestamp)
        subject => '...',    # certificate subject
        status => '...',     # verbose status of the token: EXPIRED, UPCOMING, ONLINE, OFFLINE OR UNKNOWN
    }

The online/offline status check is only possible from within the current
realm, for requests outside the current realm the status of a valid token is
always C<UNKNOWN>.

The list is sorted by C<notbefore> date, starting with the newest date.
Dates are taken from the alias table and might differ from the certificates
validity!

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm to query, defaults to the session realm

=item * C<check_online> I<Bool> - Set to 1 to get the token online status
(L<is_token_usable|OpenXPKI::Server::API2::Plugin::Token::is_token_usable/is_token_usable> is
called for each alias). The status check is only possible from within the
current session's realm, for requests regarding another realm the status is
always C<UNKNOWN>. Default: 0

=back

=cut
command "get_ca_list" => {
    pki_realm => { isa => 'AlphaPunct', },
    check_online => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my $session_pki_realm = CTX('session')->data->pki_realm;
    my $pki_realm = $params->has_pki_realm ? $params->pki_realm : $session_pki_realm;

    OpenXPKI::Exception->throw (
        message => 'Unable to use check_online from outside realm',
    ) if ($params->check_online && ($pki_realm ne $session_pki_realm));


    ##! 32: "Lookup group name for certsign"
    my $group = CTX('config')->get(['realm', $pki_realm, 'crypto', 'type', 'certsign']);

    # fetch "certsign" certificates
    my $db_results = CTX('dbi')->select(
        from_join => 'certificate identifier=identifier aliases',
        columns => [
            'certificate.data',
            'certificate.subject',
            'aliases.notbefore',
            'aliases.notafter',
            'aliases.alias',
            'aliases.identifier',
        ],
        where => {
            'aliases.pki_realm' => $pki_realm,
            'aliases.group_id'  => $group,
        },
        order_by => [ '-aliases.notbefore' ],
    );

    # check each certificate
    my @token;
    while (my $row = $db_results->fetchrow_hashref) {
        my $item = {
            alias       => $row->{alias},
            identifier  => $row->{identifier},
            subject     => $row->{subject},
            notbefore   => $row->{notbefore},
            notafter    => $row->{notafter},
            status      => 'UNKNOWN'
        };

        # Check if the token is still valid - dates are already unix timestamps
        my $now = time;
        if ($row->{notbefore} > $now) {
            $item->{status} = 'UPCOMING';
        }
        elsif ($row->{notafter} < $now) {
            $item->{status} = 'EXPIRED';
        }
        # Check if the key is usable (only if requested)
        elsif ($params->check_online) {
            try {
                my $token = CTX('crypto_layer')->get_token({
                    TYPE => 'certsign',
                    NAME => $row->{alias},
                    CERTIFICATE => {
                        DATA => $row->{data},
                        IDENTIFIER => $row->{identifier},
                    }
                } );

                # do not check if the token has no key store (remote ca)
                if ($token->get_instance->get_engine->can('get_key_store')) {
                    $item->{status} = OpenXPKI::Server::API2::Plugin::Token::Util->is_token_usable($token)
                        ? 'ONLINE'
                        : 'OFFLINE';
                }
            }
            catch ($err) {
                CTX('log')->application->error("Error testing CA token ".$row->{alias}." (API command 'get_ca_list'): $err");
            }

        }
        push @token, $item;
    }
    ##! 32: "Found tokens " . Dumper \@token
    return \@token;

};

__PACKAGE__->meta->make_immutable;
