package OpenXPKI::Server::API2::Plugin::Datapool::Util;
use Moose::Role;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::Util - Base role for datapool
related plugins that provides some utility methods

=head1 METHODS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );



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
sub assert_current_pki_realm_within_workflow {
    my ($self, $requested_pki_realm) = @_;

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
sub set_entry {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $current_pki_realm = CTX('session')->data->pki_realm;
    my $dbi = CTX('dbi');

    my $requested_pki_realm = $args->{pki_realm};
    my $namespace           = $args->{namespace};
    my $expiration_date     = $args->{expiration_date};
    my $encrypt             = $args->{encrypt};
    my $force               = $args->{force};
    my $key                 = $args->{key};
    my $value               = $args->{value};

    # primary key for database
    my $key_values = {
        'pki_realm'    => $requested_pki_realm,
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

    # sanitize value to store
    if ( ref $value ne '' ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_VALUE_TYPE',
            params => {
                PKI_REALM  => $requested_pki_realm,
                NAMESPACE  => $namespace,
                KEY        => $key,
                VALUE_TYPE => ref $value,
            },
        );
    }

    # check for illegal characters - not neccesary if we encrypt the value
    if ( !$encrypt and ($value =~ m{ (?:\p{Unassigned}|\x00) }xms )) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_ILLEGAL_DATA",
            params => {
                PKI_REALM => $requested_pki_realm,
                NAMESPACE => $namespace,
                KEY       => $key,
            },
        );
    }

    if ( defined $encrypt ) {
        if ( $encrypt !~ m{ \A (?:current_symmetric_key|password_safe) \z }xms )
        {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_ENCRYPTION_MODE',
                params => {
                    PKI_REALM       => $requested_pki_realm,
                    NAMESPACE       => $namespace,
                    KEY             => $key,
                    ENCRYPTION_MODE => $encrypt,
                },
            );
        }
    }

    if ( defined $expiration_date and $expiration_date < time ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
            params => {
                PKI_REALM       => $requested_pki_realm,
                NAMESPACE       => $namespace,
                KEY             => $key,
                EXPIRATION_DATE => $expiration_date,
            },
        );
    }

    my $encryption_key_id = '';

    if ($encrypt) {
        my $token = $self->api->get_default_token();

        if ( $encrypt eq 'current_symmetric_key' ) {

            my $encryption_key = $self->get_current_encryption_key($current_pki_realm);
            my $keyid = $encryption_key->{KEY_ID};

            $encryption_key_id = $keyid;

            ##! 16: 'setting up volatile vault for symmetric encryption'
            my $vault = OpenXPKI::Crypto::VolatileVault->new( { %{$encryption_key}, TOKEN => $token, } );

            $value = $vault->encrypt($value);

        }
        elsif ( $encrypt eq 'password_safe' ) {

            # prefix 'p7' for PKCS#7 encryption

            my $safe_id = $self->api->get_token_alias_by_type(type => 'datasafe');
            $encryption_key_id = 'p7:' . $safe_id;

            my $cert = $self->api->get_certificate_for_alias(alias => $safe_id);

            ##! 16: 'cert: ' . $cert
            if ( !defined $cert ) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_CERT_NOT_AVAILABLE',
                    params => {
                        PKI_REALM => $requested_pki_realm,
                        NAMESPACE => $namespace,
                        KEY       => $key,
                        SAFE_ID   => $safe_id,
                    },
                );
            }

            ##! 16: 'asymmetric encryption via passwordsafe ' . $safe_id
            $value = $token->command({
                COMMAND => 'pkcs7_encrypt',
                CERT    => $cert->{data},
                CONTENT => $value,
            });
        }
    }

    CTX('log')->system()->debug("Writing data pool entry [$requested_pki_realm:$namespace:$key]");

    my $data_values = {
        datapool_value  => $value,
        encryption_key  => $encryption_key_id,
        last_update     => time,
        notafter        => $expiration_date // undef,
    };

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

=head2 get_current_encryption_key

Returns a I<HashRef> with KEY, IV and ALGORITHM (directly usable by
VolatileVault) containing the currently used symmetric encryption
key for encrypting data pool values.

=cut
sub get_current_encryption_key {
    ##! 1: 'start'
    my ($self, $realm, $args) = @_;

    my $token = $self->api->get_default_token();

    # FIXME - Realm Switch
    # get symbolic name of current password safe (e. g. 'passwordsafe1')
    my $safe_id = $self->api->get_token_alias_by_type(type => 'datasafe');

    ##! 16: 'current password safe id: ' . $safe_id

    # the password safe is only used to encrypt the key for a symmetric key
    # (volatile vault). using such a key should speed up encryption and
    # reduce data size.

    my $associated_vault_key;
    my $associated_vault_key_id;

    # check if we already have a symmetric key for this password safe
    ##! 16: 'fetch associated symmetric key for password safe: ' . $safe_id
    my $data = $self->api->get_data_pool_entry(
        pki_realm => $realm,
        namespace => 'sys.datapool.pwsafe',
        key       => 'p7:' . $safe_id,
    );

    $associated_vault_key_id = $data->{value} if defined $data;
    ##! 16: 'got associated vault key: ' . $associated_vault_key_id

    if (not defined $associated_vault_key_id ) {
        ##! 16: 'first use of this password safe, generate a new symmetric key'
        my $associated_vault = OpenXPKI::Crypto::VolatileVault->new( {
            TOKEN      => $token,
            EXPORTABLE => 1,
        } );

        $associated_vault_key = $associated_vault->export_key();
        $associated_vault_key_id = $associated_vault->get_key_id( { LONG => 1 } );

        # prepare return value correctly
        $associated_vault_key->{KEY_ID} = $associated_vault_key_id;

        # save password safe -> key id mapping
        $self->set_entry( {
            pki_realm => $realm,
            namespace => 'sys.datapool.pwsafe',
            key       => 'p7:' . $safe_id,
            value     => $associated_vault_key_id,
        } );

        # save this key for future use
        $self->set_entry( {
            pki_realm => $realm,
            namespace => 'sys.datapool.keys',
            key       => $associated_vault_key_id,
            encrypt   => 'password_safe',
            value     => join( ':',
                $associated_vault_key->{ALGORITHM},
                $associated_vault_key->{IV},
                $associated_vault_key->{KEY}
            ),
        } );
    }
    else {
        # symmetric key already exists, check if we have got a cached
        # version in the SECRET pool
        my $secret_id = $associated_vault_key_id. ':'. CTX('volatile_vault')->ident();

        my $cached_key = CTX('dbi')->select_one(
            from => 'secret',
            columns => [ '*' ],
            where => {
                pki_realm => $realm,
                group_id  => $secret_id,
            }
        );

        my ($algorithm, $iv, $key);

        if ($cached_key) {
            ##! 16: 'decryption key cache hit'
            # get key from secret cache
            my $decrypted_key = CTX('volatile_vault')->decrypt( $cached_key->{data} );
            ( $algorithm, $iv, $key ) = split( /:/, $decrypted_key );
        }
        else {
            ##! 16: 'decryption key cache miss for ' .$associated_vault_key_id
            # recover key from password safe
            # symmetric key already exists, recover it from password safe
            my $data = $self->api->get_data_pool_entry(
                pki_realm => $realm,
                namespace => 'sys.datapool.keys',
                key       => $associated_vault_key_id,
            );

            if (not defined $data) {
                # should not happen, we have no decryption key for this encrypted value
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CURRENT_DATA_POOL_ENCRYPTION_KEY_SYMMETRIC_ENCRYPTION_KEY_NOT_AVAILABLE',
                    params => {
                        requested_realm => $realm,
                        namespace       => 'sys.datapool.keys',
                        key             => $associated_vault_key_id,
                    },
                    log => { priority => 'fatal', facility =>  'system' },
                );
            }

            # cache encryption key in volatile vault
            eval {
                CTX('dbi')->insert(
                    into => 'secret',
                    values => {
                        data => CTX('volatile_vault')->encrypt($data->{value}),
                        pki_realm => $realm,
                        group_id  => $secret_id,
                    },
                );
            };

            ( $algorithm, $iv, $key ) = split( /:/, $data->{value} );
        }

        $associated_vault_key = {
            KEY_ID    => $associated_vault_key_id,
            ALGORITHM => $algorithm,
            IV        => $iv,
            KEY       => $key,
        };
    }

    return $associated_vault_key;
}

1;
