package OpenXPKI::Server::API2::Plugin::Datapool::Util;
use Moose::Role;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::Util - Base role for datapool
related plugins that provides some utility methods

=head1 METHODS

=cut

# Core modules

# CPAN modules
use Type::Params qw( signature_for );

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

# Feature::Compat::Try should be done last to safely disable warnings
use Feature::Compat::Try;

# should be done after imports to safely disable warnings in Perl < 5.36
use experimental 'signatures';

=head1 DESCRIPTION

=head2 assert_current_pki_realm_within_workflow

If the calling code is within OpenXPKI::Server::Workflow namespace, check
whether the requested PKI realm matches the current one.

B<Parameters>

=over

=item * C<$caller> I<ArrayRef> - info of the API command caller as returned by
Perls caller()

=item * C<$requested_pki_realm> I<Str> - PKI realm to check

=back

=cut
signature_for assert_current_pki_realm_within_workflow => (
    method => 1,
    positional => [ 'Str' ],
);
sub assert_current_pki_realm_within_workflow ($self, $requested_pki_realm) {
    # access to the _global realm is always allowed
    return 1 if $requested_pki_realm eq '_global';

    my @caller = $self->rawapi->my_caller(1); # who called our calling code?

    # if there is no caller left (shouldn't happen)
    return 1 unless scalar @caller;

    # if caller is NOT within Workflow namespace
    return 1 unless $caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms;

    # if Workflow: check
    my $current_pki_realm = CTX('session')->data->pki_realm;
    return 1 if $requested_pki_realm eq $current_pki_realm;

    OpenXPKI::Exception->throw(
        message => 'Requested PKI realm must match current one if datapool is accessed from within OpenXPKI::Server::Workflow',
        params => {
            called_from     => sprintf("%s:%s", @caller[1,2]),
            requested_realm => $requested_pki_realm,
            current_realm   => $current_pki_realm,
        },
    );
}

=head2 get_entry

Fetches a value from the datapool DB table - hides expired items

=cut
signature_for get_entry => (
    method => 1,
    positional => [ 'Str', 'Str', 'Str' ],
);
sub get_entry ($self, $realm, $namespace, $key) {
    return CTX('dbi')->select_one(
        from  => 'datapool',
        columns => [ '*' ],
        where => {
            pki_realm    => $realm,
            namespace    => $namespace,
            datapool_key => $key,
            notafter => [ { '>' => time }, undef ],
        },
    );
}

=head2 set_entry

internal worker function, accepts more parameters than the API function
named attributes:
encrypt =>
  not set, undefined -> do not encrypt value
  'current_symmetric_key' -> encrypt using the current symmetric key
                             associated with the current password safe
  'password_safe'         -> encrypt using the current password safe
                             (asymmetrically)

=cut
signature_for set_entry => (
    method => 1,
    named => [
        pki_realm       => 'Str',
        namespace       => 'Str',
        key             => 'Str',
        value           => 'Str | Undef',
        enc_key_id      => 'Optional[ Str | Undef ]',
        expiration_date => 'Optional[ Int ]',
        force           => 'Optional[ Bool ]',
    ],
);
sub set_entry ($self, $arg) {
    my $dbi = CTX('dbi');

    my $realm      = $arg->pki_realm;
    my $namespace  = $arg->namespace;
    my $expiry     = $arg->expiration_date;
    my $enc_key_id = $arg->enc_key_id;
    my $force      = $arg->force;
    my $key        = $arg->key;
    my $value      = $arg->value;

    # primary key for database
    my $key_values = {
        'pki_realm'    => $realm,
        'namespace'    => $namespace,
        'datapool_key' => $key,
    };

    # undefined or missing value: delete entry
    if ( not defined($value) or $value eq '' ) {
        eval {
            $dbi->delete(from => 'datapool', where => $key_values );
        };
        return 1;
    }

    ##! 32: "writing data pool entry: realm=$realm / namespace=$namespace / key=$key";

    my $data_values = {
        datapool_value  => $value,
        encryption_key  => $enc_key_id,
        last_update     => time,
        notafter        => $expiry // undef,
    };

    ##! 64: $data_values

    if ($force) {
        # force = allow overwriting entries
        $dbi->merge(
            into    => 'datapool',
            set     => $data_values,
            where   => $key_values,
        );
    }
    else {
        $dbi->insert(
            into    => 'datapool',
            values  => { %$key_values, %$data_values },
        );
    }

    return 1;
}

=head2 cleanup

Clean up data pool (delete expired entries).

=cut
sub cleanup {
    my ($self) = @_;
    CTX('dbi')->delete(
        from  => 'datapool',
        where => { notafter => { '<' => time } },
    );
    return 1;
}

=head2 get_realm_encryption_key

Fetches or creates a symmetric encryption key for encrypting datapool values in
the given PKI realm.

Returns a I<HashRef> directly usable by L<OpenXPKI::Crypto::VolatileVault>'s
constructor:

    {
        KEY_ID    => '...',
        ALGORITHM => '...',
        IV        => '...',
        KEY       => '...',
    }

Creates a new key for the PKI realm if necessary.

=cut
signature_for get_realm_encryption_key => (
    method => 1,
    positional => [ 'Str' ],
);
sub get_realm_encryption_key ($self, $realm) {
    my $token = $self->api->get_default_token();

    # get symbolic name of current password safe (e.g. 'passwordsafe1')
    my $safe_id = $self->get_active_safe_id();

    ##! 16: 'current password safe id: ' . $safe_id

    # the password safe is only used to encrypt the key for a symmetric key
    # (volatile vault). using such a key should speed up encryption and
    # reduce data size.

    my $result;

    # check if we already have a symmetric key for this password safe
    ##! 16: 'fetch associated symmetric key for password safe: ' . $safe_id
    my $data = $self->api->get_data_pool_entry(
        pki_realm => $realm,
        namespace => 'sys.datapool.pwsafe',
        key       => 'p7:' . $safe_id,
    );

    #
    # Fetch and return existing key
    #
    if ($data) {
        my $key_id = $data->{value};
        ##! 16: 'got associated vault key: ' . $key_id
        my $keyinfo = $self->fetch_symmetric_key($realm, $key_id);
        return {
            KEY_ID    => $key_id,
            ALGORITHM => $keyinfo->{alg},
            IV        => $keyinfo->{iv},
            KEY       => $keyinfo->{key},
        };
    }
    #
    # Create new key
    #
    ##! 16: 'first use of this password safe, generate a new symmetric vault key'

    my $key_config = CTX('config')->get_hash(["system","datavault","enc_key"]);
    my $expiry_date = 0;

    if ($key_config->{expiration_date}) {
        $expiry_date = OpenXPKI::DateTime::get_validity({
            VALIDITY => $key_config->{expiration_date},
            VALIDITYFORMAT => 'detect',
        })->epoch();
    }

    return $self->create_realm_encryption_key(
        pki_realm => $realm,
        safe_id => $safe_id,
        dynamic_iv => $key_config->{dynamic_iv} ? 1 : 0,
        expiration_date => $expiry_date,
    );
}

=head2 create_realm_encryption_key

Generate a new encryption key

=cut

signature_for create_realm_encryption_key => (
    method => 1,
    named => [
        safe_id         => 'Optional[ Str ]',
        pki_realm       => 'Optional[ Str ]', { default => sub { CTX('session')->data->pki_realm } },
        dynamic_iv      => 'Optional[ Bool ]', { default => 0 },
        expiration_date => 'Optional[ Int ]',
    ],
);
sub create_realm_encryption_key ($self, $arg) {
    my $safe_id = $arg->safe_id || $self->get_active_safe_id;
    ##! 16: 'generate a new symmetric vault key'
    my $associated_vault = OpenXPKI::Crypto::VolatileVault->new( {
        TOKEN      => $self->api->get_default_token,
        ($arg->dynamic_iv ? (IV => undef) : ()),
        EXPORTABLE => 1,
    } );

    my $result = $associated_vault->export_key;
    my $key_id = $associated_vault->get_key_id({ LONG => 1 });

    # save this key for future use
    my $enc_value = $self->encrypt_passwordsafe($safe_id, join(':', $result->{ALGORITHM}, ($result->{IV} || ''), $result->{KEY}));
    ##! 16: "Storing vault key for password safe $safe_id to datapool"
    $self->set_entry(
        pki_realm  => $arg->pki_realm,
        namespace  => 'sys.datapool.keys',
        key        => $key_id,
        value      => $enc_value,
        enc_key_id => 'p7:' . $safe_id, # 'p7' = PKCS#7 encryption,
    );

    # save password safe -> key id mapping
    $self->set_entry(
        pki_realm => $arg->pki_realm,
        namespace => 'sys.datapool.pwsafe',
        key       => 'p7:' . $safe_id, # 'p7' = PKCS#7 encryption,
        value     => $key_id,
        $arg->expiration_date ? (expiration_date => $arg->expiration_date) : (),
        force => 1,
    );

    CTX('log')->system()->info(sprintf('New datapool encryption token was created (Token: %s, Key: %s)', $safe_id, $key_id));
    CTX('log')->audit('system')->info('New datapool encryption token was created', {
        token  => $safe_id,
        keyid  => $key_id,
    });

    # add key ID
    $result->{KEY_ID} = $key_id;

    return $result;

}

=head2  rekey_realm_encryption_key

Wrap the "inner" symmetric keys from one datavault token to another one

=cut
signature_for rekey_realm_encryption_key => (
    method => 1,
    positional => [ 'Str', 'Optional[ Str ]' ],
);
sub rekey_realm_encryption_key ($self, $key_id, $safe_id) {
    my $realm = CTX('session')->data->pki_realm;

    my $result = $self->get_entry($realm, 'sys.datapool.keys', $key_id);
    OpenXPKI::Exception->throw(message => 'Key not found', params => { key => $key_id })
        unless($result);

    my ($old_safe_id) = $result->{encryption_key} =~ m{ \A p7:(.*) }xms;
    my $plain_key_value = $self->decrypt_passwordsafe($old_safe_id, $result->{datapool_value});

    # use the safe_id from the arguments or get the current one
    $safe_id ||= $self->get_active_safe_id();

    if ('p7:'.$safe_id eq $result->{encryption_key}) {
        CTX('log')->system()->warn(sprintf('Rekey request with target equal current token (Token: %s, Key: %s)', $safe_id, $key_id));
        return;
    }

    # store the old key as backup - as we do not set force this can crash on an old backup
    $self->set_entry(
        pki_realm  => $realm,
        namespace  => 'sys.datapool.keys.backup',
        key        => $key_id,
        value      => $result->{datapool_value},
        enc_key_id => $result->{encryption_key},
    );

    my $enc_value = $self->encrypt_passwordsafe($safe_id, $plain_key_value);
    ##! 16: "Save rekeyed vault key $key_id to $safe_id"
    $self->set_entry(
        pki_realm  => $realm,
        namespace  => 'sys.datapool.keys',
        key        => $key_id,
        value      => $enc_value,
        enc_key_id => 'p7:' . $safe_id, # 'p7' = PKCS#7 encryption,
        force => 1,
    );

    CTX('log')->audit('system')->info('Datapool encryption key was rekeyed', {
        source => $old_safe_id,
        target => $safe_id,
        keyid  => $key_id,
    });

}

# Asymmetric encryption using the given token
# Note: encryption does not need any key an can be done using
# the keyless default token.
signature_for encrypt_passwordsafe => (
    method => 1,
    positional => [ 'Str', 'Str' ],
);
sub encrypt_passwordsafe ($self, $safe_id, $value) {
    # $safe_id is the alias name of the token, e.g. server-vault-1
    my $cert = $self->api->get_certificate_for_alias(alias => $safe_id);
    OpenXPKI::Exception->throw(message => 'Certificate not found', params => { alias => $safe_id })
        unless $cert && $cert->{data};
    ##! 16: "retrieved cert: id = " . $cert->{identifier}


    # support OAEP padding mode - IMHO superfluous but required by some HSM vendors
    # and regulatory bodies to meet formal requirements
    # #TODO this code is currently duplicated in is_token_usable - needs cleanup
    my %PADDING;
    my $padding_config = CTX('config')->get_hash(["system","datavault","padding"]);
    if ($padding_config && $padding_config->{mode}) {
        my $mode = $padding_config->{mode};
        delete $padding_config->{mode};
        if ($mode eq 'oaep') {
            $PADDING{PADDING} = 'oaep';
            if (keys %{$padding_config}) {
                $PADDING{PADDING_OPTIONS} = $padding_config
            }
        } elsif ($mode ne 'pkcs1') {
            OpenXPKI::Exception->throw(
                message => 'Unsupported padding mode for DataVault',
                params => { mode => $mode }
            );
        }
    }

    ##! 16: 'asymmetric encryption via passwordsafe ' . $safe_id
    return $self->api->get_default_token->command({
        COMMAND => 'pkcs7_encrypt',
        CERT    => $cert->{data},
        CONTENT => $value,
        %PADDING
    });
}

# Asymmetric decryption using the given token
signature_for decrypt_passwordsafe => (
    method => 1,
    positional => [ 'Str', 'Str' ],
);
sub decrypt_passwordsafe ($self, $safe_id, $enc_value) {
    # $safe_id is the alias name of the token, e.g. server-vault-1
    my $safe_token = CTX('crypto_layer')->get_token({ TYPE => 'datasafe', 'NAME' => $safe_id})
        or OpenXPKI::Exception->throw(
            message => 'Token of password safe referenced in datapool entry not available',
            params => { token_id  => $safe_id }
        );

    ##! 16: "asymmetric decryption via passwordsafe '$safe_id'"
    my $value;
    try {
        $value = $safe_token->command({ COMMAND => 'pkcs7_decrypt', PKCS7 => $enc_value });
    }
    catch ($err) {
        if (blessed $err and $err->isa('OpenXPKI::Exception')) {
            if ($err->message eq 'I18N_OPENXPKI_TOOLKIT_COMMAND_FAILED') {
                OpenXPKI::Exception->throw(
                    message => 'Encryption key needed to decrypt password safe entry is unavailable',
                    params => { token_id => $safe_id }
                );
            }
        }
        die $err;
    }

    return $value;
}

=head2 fetch_symmetric_key

Returns a I<HashRef> containing an existing symmetric encryption key for
encrypting datapool values either from the server cache or from the datapool.

=cut
signature_for fetch_symmetric_key => (
    method => 1,
    positional => [ 'Str', 'Str' ],
);
sub fetch_symmetric_key ($self, $realm, $key_id) {
    ##! 16: "fetching symmetric key $key_id"

    # Symmetric keys are cached via the server volatile vault.
    # If asked to decrypt a value via a symmetric key, we first check if the
    # key is already cached by the server instance:
    # If cached:
    #   Directly obtain key from volatile vault.
    # If not cached:
    #   Obtain the key from the data pool (may result in another call of
    #   "get_data_pool_entry" that fetches encrypted values and does an
    #   asymmetric decryption via password safe key).
    #   Once we have obtained the encryption key via the data pool chain we
    #   store it in the server volatile vault for faster access.

    # ID for caching the key
    # We append the vault's ident to prevent collisions in DB
    # TODO: should be replaced by static server id
    my $secret_id = $key_id. ':'. CTX('volatile_vault')->ident();
    ##! 16: "secret id = $secret_id"

    # query server cache for the key
    my $key_str = $self->_get_cached_key($realm, $secret_id);

    # if not cached: obtain it from datapool (will decrypt it asymmetrically using volatile vault token)
    if (not $key_str) {
        ##! 32: "key is NOT cached, obtaining from datapool"
        # determine encryption key
        my $key_data = $self->api->get_data_pool_entry(
            pki_realm => $realm,
            namespace => 'sys.datapool.keys',
            key       => $key_id,
        )
            # should not happen: we have no decryption key for this encrypted value
            or OpenXPKI::Exception->throw(
                message => 'Key for symmetric encryption not found in datapool',
                params => {
                    requested_realm => $realm,
                    namespace       => 'sys.datapool.keys',
                    key             => $key_id,
                },
                log => { priority => 'fatal', facility => 'system' },
            );
        ##! 16: "Returned data: ".Dumper($key_data)
        $key_str = $key_data->{value};
        $self->_cache_key($realm, $secret_id, $key_str); # cache encryption key in volatile vault
    }
    ##! 32: "key = $key_str"

    my ( $algorithm, $iv, $key ) = split( /:/, $key_str );
    return {
        alg => $algorithm,
        iv  => $iv || undef, # undef for dynamic generation
        key => $key,
    };
}

sub get_active_safe_id {
    my $self = shift;

    # if ignore_validity is set we accept expired tokens, see #744
    my %validity;
    if (CTX('config')->get(["system","datavault","ignore_validity"])) {
        %validity = ( validity => {
            notbefore => undef,
            notafter => DateTime->from_epoch( epoch => 0 ),
        });
    }

    return $self->api->get_token_alias_by_type(
        type => 'datasafe', %validity
    );
}

# Read encryption from volatile vault and decrypt it.
# Returns the decrypted cached key or undef if non was found
signature_for _get_cached_key => (
    method => 1,
    positional => [ 'Str', 'Str' ],
);
sub _get_cached_key ($self, $realm, $secret_id) {
    ##! 16: "Fetching cached key from database"

    my $cached_key = CTX('dbi')->select_one(
        from => 'secret',
        columns => [ 'data' ],
        where => {
            pki_realm => $realm,
            group_id  => $secret_id,
        }
    );
    if (not $cached_key) {
        ##! 16: "Encryption key $secret_id not in server cache"
        return;
    }

    ##! 16: "Encryption key $secret_id found in server cache"
    my $decrypted_key = CTX('volatile_vault')->decrypt($cached_key->{data});
    ##! 32: "decrypted_key $decrypted_key"
    return $decrypted_key;
}

# Cache encryption key in volatile vault
signature_for _cache_key => (
    method => 1,
    positional => [ 'Str', 'Str', 'Str' ],
);
sub _cache_key ($self, $realm, $secret_id, $key) {
    ##! 16: "Caching encryption key $secret_id"
    eval {
        CTX('dbi')->insert(
            into => 'secret',
            values => {
                data => CTX('volatile_vault')->encrypt($key),
                pki_realm => $realm,
                group_id  => $secret_id,
            },
        );
    };
}

1;
