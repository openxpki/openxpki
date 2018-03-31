package OpenXPKI::Server::API2::Plugin::Datapool::get_data_pool_entry;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::get_data_pool_entry

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


=head1 COMMANDS

=head2 get_data_pool_entry

Searches the specified key in the datapool and returns a I<HashRef>.

    my $info = CTX('api2')->get_data_pool_entry(
        pki_realm => $pki_realm,
        namespace => 'workflow.foo.bar',
        key => 'myvariable',
    );

Returns:

    {
        pki_realm       => '...',   # PKI realm
        namespace       => '...',   # namespace
        key             => '...',   # data pool key
        value           => '...',   # value
        encrypted       => 1,       # 1 or 0, depending on if it was encrypted
        encryption_key  => '...',   # encryption key id used (may not be available)
        mtime           => 12345,   # date of last modification (epoch)
        expiration_date => 12356,   # date of expiration (epoch)
    }

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

If the API is called directly from OpenXPKI::Server::Workflow only the PKI realm
of the currently active session is accepted.

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=item * C<key> I<Str> - entry key

=back

=cut
command "get_data_pool_entry" => {
    # TODO Change type of "key" back to "AlphaPunct" once we have a private method to get encrypted data pool entries (where keys have more characters)
    key       => { isa => 'Str', required => 1, },
    namespace => { isa => 'AlphaPunct', required => 1, },
    pki_realm => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
} => sub {
    my ($self, $params) = @_;

    my $namespace = $params->namespace;
    my $key       = $params->key;

    my $requested_pki_realm = $params->pki_realm;
    my $dbi = CTX('dbi');

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);

    CTX('log')->system()->debug("Reading data pool entry [$requested_pki_realm:$namespace:$key]");


    my $where = {
        pki_realm    => $requested_pki_realm,
        namespace    => $namespace,
        datapool_key => $key,
    };

    my $result = $dbi->select_one(
        from  => 'datapool',
        columns => [ '*' ],
        where => $where,
    );

    # no entry found, do not raise exception but simply return undef
    unless ($result) {
        CTX('log')->system()->debug("Requested data pool entry [$requested_pki_realm:$namespace:$key] not available");

        return;
    }

    my $value          = $result->{datapool_value};
    my $encryption_key = $result->{encryption_key};

    my $encrypted = 0;
    if ($encryption_key) {
        $encrypted = 1;

        my $token = CTX('api')->get_default_token();

        if ( $encryption_key =~ m{ \A p7:(.*) }xms ) {

            # asymmetric decryption
            my $safe_id = $1; # This is the alias name of the token, e.g. server-vault-1
            my $safe_token = CTX('crypto_layer')->get_token({ TYPE => 'datasafe', 'NAME' => $safe_id});

            if ( !defined $safe_token ) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_ENTRY_PASSWORD_TOKEN_NOT_AVAILABLE',
                    params => {
                        PKI_REALM => $requested_pki_realm,
                        NAMESPACE => $namespace,
                        KEY       => $key,
                        SAFE_ID   => $safe_id,
                    }
                );
            }
            ##! 16: 'asymmetric decryption via passwordsafe ' . $safe_id
            eval {
                $value = $safe_token->command(
                    {
                        COMMAND => 'pkcs7_decrypt',
                        PKCS7   => $value,
                    }
                );
            };
            if ( my $exc = OpenXPKI::Exception->caught() ) {
                if ( $exc->message() eq 'I18N_OPENXPKI_TOOLKIT_COMMAND_FAILED' )
                {

                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_ENTRY_ENCRYPTION_KEY_UNAVAILABLE',
                        params => {
                            PKI_REALM => $requested_pki_realm,
                            NAMESPACE => $namespace,
                            KEY       => $key,
                            SAFE_ID   => $safe_id,
                        }
                    );
                }

                $exc->rethrow();
            }

        }
        else {

            # symmetric decryption

            # optimization: caching the symmetric key via the server
            # volatile vault. if we are asked to decrypt a value via
            # a symmetric key, we first check if we have the symmetric
            # key cached by the server instance. if this is the case,
            # directly obtain the symmetric key from the volatile vault.
            # if not, obtain the symmetric key from the data pool (which
            # may result in a chained call of get_data_pool_entry with
            # encrypted values and likely ends with an asymmetric decryption
            # via the password safe key).
            # once we have obtained the encryption key via the data pool chain
            # store it in the server volatile vault for faster access.

            my $algorithm;
            my $key;
            my $iv;

            # add the vaults ident to prevent collisions in DB
            # TODO: should be replaced by static server id
            my $secret_id = $encryption_key. ':'. CTX('volatile_vault')->ident();
            ##! 16: 'Secret id ' . $secret_id

            my $cached_key = $dbi->select_one(
                from => 'secret',
                columns => [ 'data' ],
                where => {
                    pki_realm => $requested_pki_realm,
                    group_id  => $secret_id,
                }
            );
            ##! 32: 'Cache result ' . Dumper $cached_key

            if ($cached_key) {
                # key was cached by volatile vault
                ##! 16: 'encryption key cache hit'

                my $decrypted_key =
                  CTX('volatile_vault')->decrypt( $cached_key->{data} );

                ##! 32: 'decrypted_key ' . $decrypted_key
                ( $algorithm, $iv, $key ) = split( /:/, $decrypted_key );
            }
            else {
                ##! 16: 'encryption key cache miss'
                # key was not cached by volatile vault, obtain it the hard
                # way

                # determine encryption key
                my $key_data = $self->api->get_data_pool_entry(
                    pki_realm => $requested_pki_realm,
                    namespace => 'sys.datapool.keys',
                    key       => $encryption_key,
                );

                if (not defined $key_data) {

                    # should not happen, we have no decryption key for this
                    # encrypted value
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_DATA_POOL_SYMMETRIC_ENCRYPTION_KEY_NOT_AVAILABLE',
                        params => {
                            REQUESTED_REALM => $requested_pki_realm,
                            NAMESPACE       => 'sys.datapool.keys',
                            KEY             => $encryption_key,
                        },
                        log => {
                            priority => 'fatal',
                            facility => 'system',
                        },
                    );
                }

                # prepare key
                ( $algorithm, $iv, $key ) = split( /:/, $key_data->{value} );

                # cache encryption key in volatile vault
                eval {
                    $dbi->insert(
                        into => 'secret',
                        values => {
                            data => CTX('volatile_vault')->encrypt( $key_data->{value} ),
                            pki_realm => $requested_pki_realm,
                            group_id  => $secret_id,
                        },
                    );
                };
            }

            ##! 16: 'setting up volatile vault for symmetric decryption'
            my $vault = OpenXPKI::Crypto::VolatileVault->new(
                {
                    ALGORITHM => $algorithm,
                    KEY       => $key,
                    IV        => $iv,
                    TOKEN     => $token,
                }
            );

            $value = $vault->decrypt($value);
        }
    }

    ##! 32: 'datapool value is ' . Dumper %return_value
    return {
        pki_realm => $result->{pki_realm},
        namespace => $result->{namespace},
        key       => $result->{datapool_key},
        encrypted => $encrypted,
        mtime     => $result->{last_update},
        value     => $value,
        $encrypted
            ? ( encryption_key => $result->{encryption_key} ) : (),
        $result->{notafter}
            ? ( expiration_date => $result->{notafter} ) : (),
    };
};

__PACKAGE__->meta->make_immutable;
