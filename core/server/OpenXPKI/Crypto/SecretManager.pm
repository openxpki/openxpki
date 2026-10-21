package OpenXPKI::Crypto::SecretManager;
use OpenXPKI -class;

# Core modules
use Digest::SHA qw( sha256_hex sha1_base64 );
use Time::HiRes;

# CPAN modules
use Crypt::Argon2;
use Crypt::PK::ECC;
use Template;

# Project modules
use OpenXPKI::Control::Server;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::FileUtils;
use OpenXPKI::Defaults;

=head1 NAME

OpenXPKI::Crypto::SecretManager - Secret manager

=head1 Description

Management of I<secrets>, i.e. passphrases/keys for cryptographic tokens.

=head1 ATTRIBUTES

=head2 default_token

Required: instance of I<OpenXPKI::Crypto::API>.

=cut

has default_token => (
    is => 'rw',
    isa => 'OpenXPKI::Crypto::API',
    required => 1,
);

# tracks for every realm if all secrets were (bulk) queried from config
has all_secrets_queried => (
    is => 'rw',
    isa => 'HashRef[Bool]',
    init_arg => undef,
    default => sub { {} },
);

has secrets => (
    is => 'rw',
    isa => 'HashRef[Str]',
    init_arg => undef,
    default => sub { {} },
);

=head1 METHODS

=head2 _get_secret_def ($alias, $return_undef_if_not_found)

Returns the configuration I<HashRef> of the secret specified by the given name
or C<undef> if realm or secret do not exist.

Upon first call this method tries to load the secret's setup from configuration
and the serialized data from the cache.

=cut

sub _get_secret_def ($self, $alias, $return_undef_if_not_found = 0) {
    my $def;

    my $realm = CTX('session')->data->pki_realm;
    ##! 2: "get realm = $realm, alias = $alias"

    # Return the known data
    if (defined $self->secrets->{$realm} and defined $self->secrets->{$realm}->{$alias}) {
        $def = $self->secrets->{$realm}->{$alias};
        ##! 16: "returning cached value: " . (ref $def ? "(config exists)" : "(config does not exist)")
    }
    # Try to load secret definitions that were not queried yet
    else {
        ##! 16: "query definition '$realm.crypto.secr3t.$alias'"
        $def = $self->_load(['crypto', 'secret'], $realm, $alias);

        # Handle imports (i.e. references to global definition)
        if (defined $def and $def->{import}) {
            ##! 16: "'import' statement - query definition 'system.crypto.secr3t.$alias"
            my $global_def = $self->_load(['system', 'crypto', 'secret'], '_global', $alias);
            if ($global_def) {
                ##! 16: "global definition successfully imported"
                $self->_set_secret('_global', $alias, $global_def);
                my $export = $def->{export} && $global_def->{export};
                # replace existing definition with imported one
                $def = $global_def;
                $def->{export} = $export;
            }
            else {
                ##! 16: "no global definition found"
                $def = undef;
            }
        }

        if (not defined $def) {
            if ($return_undef_if_not_found) {
                $def = 0; # 0 = flag that we already tried to load this one
            }
            else {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SECRET_GROUP_DOES_NOT_EXIST",
                    params => { REALM => $realm, GROUP => $alias },
                )
            }
        }
        $self->_set_secret($realm, $alias, $def);
    }

    return ref $def ? $def : undef;
}

=head2 _set_secret ($realm, $group, $def)

Internally store the given C<$def> I<HashRef> under the given realm/group
name.

=cut

sub _set_secret ($self, $realm, $group, $def) {
    $self->secrets->{$realm} //= {};
    $self->secrets->{$realm}->{$group} = $def;
}

=head2 _load ($alias)

Create and return the internal config I<HashRef> incl. object for the secret
of the given name.

Returns:

    {
        ... # options from configuration file
        _alias => STR,
        _realm => STR,
        _ref => OBJECT with Moose role OpenXPKI::Crypto::SecretRole,
    }

=cut

sub _load ($self, $confpath, $realm, $alias) {
    ##! 1: "start: alias '$realm.$alias'"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_MISSING_GROUP"
    ) unless $alias;

    my $def = CTX('config')->get_hash([ @{ $confpath }, $alias ]);

    return unless $def;
    return $def if $def->{import}; # stop processing as we'll throw away this hash if a global secret is referenced

    # defaults
    $def->{cache_check_if_complete} //= $OpenXPKI::Defaults::CRYPTO_SECRET_CACHE_CHECK_IF_COMPLETE;
    $def->{cache_check} //= $OpenXPKI::Defaults::CRYPTO_SECRET_CACHE_CHECK;

    # force "no cache" for literal secrets
    $def->{cache} = "none" if ($def->{method} // "") eq "literal";

    # internal meta data
    $def->{_alias} = $alias;
    $def->{_realm} = $realm;

    ##! 2: "initialize object"
    my $secret = $self->_create_object($def);
    $def->{_ref} = $secret;

    ##! 2: "load serialized data into object (if any)"
    my $serialized = $self->_load_from_cache($def->{_realm}, $def->{_alias}, $def->{cache}); # might be undef
    $secret->thaw($serialized);
    $def->{_synced_with_cache} = Time::HiRes::time; # floating point time
    $def->{_cache_checksum} = sha256_hex($serialized // '');

    ##! 1: "finish"
    return $def;
}

=head2 _create_object ($def)

Returns an object with Moose role L<OpenXPKI::Crypto::SecretRole> according to
the given config data I<HashRef>.

=cut

sub _create_object ($self, $def) {
    ##! 1: "start"

    my $realm = $def->{_realm};
    my $method = lc($def->{method} || "");
    my $share_type = lc($def->{share_type} || "plain");
    my $share_store = lc($def->{share_store} || "");
    my $group = $def->{_alias};

    ##! 2: "method: $method"
    if ('literal' eq $method) {
        require OpenXPKI::Crypto::Secret::Plain;
        my $secret = OpenXPKI::Crypto::Secret::Plain->new(
            part_count => 1,
            ($def->{kcv} ? (kcv => $def->{kcv}) : ()),
        );
        if (defined $def->{value}) {
            $secret->set_secret($def->{value});
        } else {
            CTX('log')->application->warn("Creating literal secret but secret value is not specified");
        }
        return $secret;
    }
    elsif ('plain' eq $method) {
        require OpenXPKI::Crypto::Secret::Plain;
        return OpenXPKI::Crypto::Secret::Plain->new(
            # KCV and Multi-Part is not yet working
            part_count => ($def->{total_shares} || 1),
            ($def->{kcv} ? (kcv => $def->{kcv}) : ()),
        );
    }
    elsif ('kdf' eq $method) {
        require OpenXPKI::Crypto::Secret::KDF;
        ##! 32: $def->{kdf_param}
        my $secret = OpenXPKI::Crypto::Secret::KDF->new(
            ($def->{kcv} ? (kcv => $def->{kcv}) : ()),
            kdf => $def->{kdf},
            salt => $def->{salt},
            kdf_param => ($def->{kdf_param} || {}),
        );
        return $secret;
    }
    elsif ('split' eq $method) {
        my %split_secret_args = (
            quorum_k => $def->{required_shares},
            quorum_n => $def->{total_shares},
            token  => $self->default_token,
        );

        if ('plain' eq $share_type) {
            require OpenXPKI::Crypto::Secret::Split;
            return OpenXPKI::Crypto::Secret::Split->new(%split_secret_args);
        }
        elsif ('encrypted' eq $share_type) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_SHARE_STORE_MISSING"
            ) unless $def->{share_store};

            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_SHARE_NAME_MISSING"
            ) unless $def->{share_name};

            # set up filesystem or datapool backend (loader)
            my $loader;
            if ('filesystem' eq $share_store) {
                $loader = sub {
                    my ($share_name) = @_;
                    ##! 16: "loading encrypted share from filesystem: $share_name"
                    my $share;
                    try {
                        $share = OpenXPKI::FileUtils->read_file($share_name);
                    }
                    catch ($err) {
                        CTX('log')->application->warn("Could not open encrypted share: $err");
                    }
                    return $share;
                };
            }
            elsif ('datapool' eq $share_store) {
                $loader = sub {
                    my ($share_name) = @_;
                    ##! 16: "loading encrypted share from datapool: $share_name"
                    my $share = CTX('api2')->get_data_pool_entry(
                        pki_realm => $realm,        # may be '_global'
                        namespace => 'secretshare',
                        key => $share_name,
                    );
                    return unless $share;
                    return $share->{value};
                };
            }
            else {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_UNKNOWN_SHARE_STORE_TYPE"
                );
            }

            # initialize object
            require OpenXPKI::Crypto::Secret::SplitEncrypted;
            return OpenXPKI::Crypto::Secret::SplitEncrypted->new(
                %split_secret_args,
                share_names => $self->_get_encryptedshare_names(
                    $def->{share_name},
                    $group,
                    $def->{total_shares}
                ),
                encrypted_share_loader => $loader,
            );
        }
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_UNKNOWN_SHARE_TYPE"
        );
    }
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_WRONG_METHOD",
        params  => { METHOD => $method, GROUP => $group }
    );
}

=head2 _get_encryptedshare_names ($template, $alias, $count)

Uses L<Template> to render the names (or paths for encrypted share type
C<FILESYSTEM>) for all C<n> encrypted secret shares.

Returns an I<ArrayRef> of all C<n> share names.

=cut

sub _get_encryptedshare_names ($self, $template, $alias, $count) {
    my @result = ();
    ##! 16: "Generating share names from template $template (n = $count)"

    my $tt = Template->new();
    my $realm = CTX('session')->data->pki_realm;

    for (my $i = 0; $i<$count; $i++) {
        my $output = "";
        $tt->process(\$template, { ALIAS => $alias, INDEX => $i, PKI_REALM => $realm }, \$output)
            or OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_ERROR_PARSING_TEMPLATE',
                params => { TEMPLATE => $template, ERROR => $tt->error() }
            );

        if ($output) {
            chomp $output;
            # if the output is already there the user forgot to use [% INDEX %] in the template
            if (grep { $_ eq $output } @result) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_ERROR_INDEX_VARIABLE_NOT_USED',
                    params => { TEMPLATE => $template }
                );
            }
            push @result, $output;
        }
    }

    ##! 32: print "- $_\n" for @result
    return \@result;
}

=head2 _load_from_cache ($realm, $alias, $cache_type)

Try to load the secret's serialized data from the cache (session or DB).

Returns serialized secret data to be passed to
L<OpenXPKI::Crypto::SecretRole/thaw> or C<undef>.

=cut

sub _load_from_cache ($self, $realm, $alias, $cache_type) {
    OpenXPKI::Exception->throw (
        message => "No cache type given for secret",
        params  => { REALM => $realm, GROUP => $alias }
    ) unless defined $cache_type;

    $cache_type = lc($cache_type);

    ##! 2: "check cache ($cache_type) for serialized data of '$alias'"
    my $dump = "";

    if ($cache_type eq "none") {
        # literal never has/needs a cache
        return;
    }
    elsif ($cache_type eq "session") {
        ## session mode
        ##! 4: "load serialized data from session ($alias)"
        return CTX('session')->data->secret(group => $alias);
    }
    elsif ($cache_type eq "daemon") {
        ## daemon mode
        # in cluster mode or after unclean shutdown we might have items with
        # the same group name that we can not read so we add the VV key id
        my $alias = sprintf("%s:%s", CTX('volatile_vault')->get_key_id(), $alias);

        my $row = CTX('dbi')->select_one(
            from    => "secret",
            columns => [ 'data' ],
            where => {
                pki_realm => $realm, # may be '_global'
                group_id  => $alias,
            }
        );
        ##! 4: "loaded " . (length $row->{data} // 0) . " bytes of serialized data from database ($alias)"
        return $row->{data};
    }
    OpenXPKI::Exception->throw (
        message => "Unsupported cache type for secret",
        params  => { TYPE => $cache_type, REALM => $realm, GROUP => $alias }
    );
}

=head2 _save_to_cache ($realm, $alias, $cache_type, $dump)

Save the secret's serialized data to the cache (session or DB).

=cut

sub _save_to_cache ($self, $realm, $alias, $cache_type, $dump) {
    $cache_type = lc($cache_type || "");

    # FIXME Implement different storage options in role or class
    if ($cache_type eq "none") {
        # literal never has/needs a cache
    }
    elsif ($cache_type eq "session") {
        ##! 4: "store serialized data in session ($alias)"
        CTX('session')->data->secret(group => $alias, value => $dump);
        CTX('session')->persist;
    }
    elsif ($cache_type eq "daemon") {
        my $alias = sprintf("%s:%s", CTX('volatile_vault')->get_key_id(), $alias);
        ##! 4: "store " . (length $dump // 0) . " bytes of serialized data in database ($alias)"
        CTX('dbi')->merge(
            into => "secret",
            set  => { data => $dump },
            where => {
                pki_realm => $realm,
                group_id  => $alias,
            },
        );
    }
    else {
        OpenXPKI::Exception->throw (
            message => "Unsupported cache type",
            params  => { TYPE => $cache_type, GROUP => $alias }
        );
    }
}

=head2 _clear_cache ($def)

Removes the secret's serialized data from the cache (session or DB).

=cut

sub _clear_cache ($self, $def) {
    my $cache_type = lc($def->{cache} || "");
    my $realm = $def->{_realm};
    my $alias = $def->{_alias};

    # FIXME Implement different storage options in role or class
    if ($cache_type eq "none") {
        # literal never has/needs a cache
    }
    elsif ($cache_type eq "session") {
        ##! 4: "delete data from session"
        CTX('session')->data->clear( group => $alias );
        # session will be persisted in OpenXPKI::Service::Default->init()
    }
    elsif ($cache_type eq "daemon") {
        ##! 4: "delete data from database"
        my $alias = sprintf("%s:%s", CTX('volatile_vault')->get_key_id, $alias);
        my $result = CTX('dbi')->delete(
            from => "secret",
            where => {
                pki_realm => $realm,
                group_id  => $alias,
            }
        );
        ##! 4: "reload OpenXPKI"
        # Deletes secret objects from child processes
        OpenXPKI::Control::Server->new->cmd_reload;
    }
    else {
        OpenXPKI::Exception->throw (
            message => "Unsupported cache type",
            params  => { TYPE => $cache_type, GROUP => $alias }
        );
    }
}


=head2 _update_from_cache ($alias)

Update the in-memory copy of the secret with the cache value, but only if:

=over

=item * the secret is incomplete and C<cache_check>
seconds elapsed or

=item * the secret is complete but C<cache_check_if_complete> elapsed

=back

since last check.

=cut

sub _update_from_cache ($self, $def) {
    ##! 1: "start"
    my $secret = $def->{_ref};

    my $is_complete = $secret->is_complete;
    my $elapsed_since_sync = Time::HiRes::time - $def->{_synced_with_cache}//0;

    # only update if intervals elapsed
    return if (
        ($is_complete and $elapsed_since_sync < $def->{cache_check_if_complete})
        or
        (not $is_complete and $elapsed_since_sync < $def->{cache_check})
    );

    my $serialized = $self->_load_from_cache($def->{_realm}, $def->{_alias}, $def->{cache}); # might be undef
    my $checksum = sha256_hex($serialized // '');
    # only burn CPU cycles if cache did change
    if ($checksum ne ($def->{_cache_checksum}//'')) {
        $secret->clear_secret;
        $secret->thaw($serialized);
        $def->{_cache_checksum} = $checksum;
    }
    $def->{_synced_with_cache} = Time::HiRes::time; # floating point time
}

=head2 get_infos

List type and name of all secret groups in the current realm

Returns:

    {
        'my-secret' => {
            label => STR,
            type  => STR,
            complete => BOOL,
            required_parts => NUM,
            inserted_parts => NUM,
        },
        'other-secret' => {
            ...
        },
        ...
    }

=cut

sub get_infos ($self) {
    ##! 2: "init"
    my $realm = CTX('session')->data->pki_realm;

    my @name_list;
    if ($self->all_secrets_queried->{$realm}) {
        @name_list = keys %{ $self->secrets->{$realm} };
    }
    else {
        # load names of all secrets from config once
        @name_list = CTX('config')->get_keys(['crypto','secret']);
    }

    my $result;
    ##! 2: "build list:"
    for my $alias (@name_list) {
        ##! 16: "- $alias"
        my $def = $self->_get_secret_def($alias)
            or OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_GET_SECRET_GROUPS_GROUP_NOT_FOUND",
                params => { GROUP => $alias },
            );

        # read from cache in case parallel process changed something
        $self->_update_from_cache($def);

        $result->{$alias} = {
            label => $def->{label},
            type  => $def->{method},
            complete => $def->{_ref}->is_complete ? 1 : 0,
            required_parts => $def->{_ref}->required_part_count,
            inserted_parts => $def->{_ref}->inserted_part_count,
        };
    }

    $self->all_secrets_queried->{$realm} = 1; # $self->_get_secret_def() queries them all

    ##! 1: "finished"
    return $result;
}

=head2 get_required_part_count

Returns the number of required parts to complete this secret.

=cut

sub get_required_part_count ($self, $alias) {
    my $def = $self->_get_secret_def($alias);

    return $def->{_ref}->required_part_count;
}

=head2 get_inserted_part_count

Returns the number of parts that are already inserted / set.

=cut

sub get_inserted_part_count ($self, $alias) {
    my $def = $self->_get_secret_def($alias);
    $self->_update_from_cache($def);

    return $def->{_ref}->inserted_part_count;
}

=head2 is_complete ($alias)

Read current secret status from cache and check if it is complete (all parts
set / passwords entered).

Returns C<0> or C<1>.

=cut

sub is_complete ($self, $alias) {
    ##! 1: "start"
    my $def = $self->_get_secret_def($alias);
    $self->_update_from_cache($def);

    return $def->{_ref}->is_complete ? 1 : 0;
}

=head2 get_secret ($alias)

Get the plaintext value of the stored secret. This requires that the
secret was created with the "export" flag set, otherwise an exception
is thrown.

Returns the secret value or C<undef> if the secret is not complete.

=cut

sub get_secret ($self, $alias) {
    ##! 1: "start"
    my $def = $self->_get_secret_def($alias);
    $self->_update_from_cache($def);

    return undef unless $def->{_ref}->is_complete; # this reads the current value from cache

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_SECRET_GROUP_NOT_EXPORTABLE"
    ) unless $def->{export};

    return $def->{_ref}->get_secret;
}

=head2 set_part ({ GROUP, VALUE, PART })

Set the secret C<VALUE> of the given C<GROUP> (aka alias), for plain secrets
omit C<PART>.

=cut

sub set_part ($self, $args) {
    ##! 1: "start"
    my $alias = $args->{GROUP};
    my $part  = $args->{PART};
    my $value = $args->{VALUE};

    ##! 2: "init"
    my $def = $self->_get_secret_def($alias);
    $self->_update_from_cache($def); # UPDATE! (or we might operate on a stale copy)

    my $obj = $def->{_ref};

    # store in case we need to restore on failure
    my $old_secret = $obj->freeze;

    try {
        ##! 2: "setting $alias" . (defined $part ? ", part $part" : "")
        $obj->set_secret($value, $part); # $part might be undef

        $self->_save_to_cache($def->{_realm}, $def->{_alias}, $def->{cache}, $obj->freeze);
        $def->{_synced_with_cache} = Time::HiRes::time; # floating point time
    }
    catch ($err) {
        # Restore old secret
        $obj->clear_secret;
        $obj->thaw($old_secret);
        die $err;
    }
    ##! 1: "finished"
}

=head2 clear ($alias)

Purge the secret of the given name.

=cut

sub clear ($self, $alias) {
    ##! 2: "init"
    my $def = $self->_get_secret_def($alias);

    $self->_clear_cache($def);
    $def->{_synced_with_cache} = Time::HiRes::time; # floating point time

    # Clear secret data (makes it unset/incomplete again)
    $def->{_ref}->clear_secret;

    ##! 1: "finished"
}

=head2 request_transfer

Initialize a secret transfer to the current node. Creates a keypair for
negotiation of the transfer secret and writes placeholder items for this key
into the database.

=cut

sub request_transfer ($self) {
    my $realm = CTX('session')->data->pki_realm;

    my @aliases;
    for my $alias (keys %{$self->get_infos()}) {
        ##! 32: "Check if group $alias is complete"
        if (!$self->is_complete($alias)) {
            push @aliases, $alias;
        }
    }

    # no secret groups to load
    if (scalar @aliases == 0) {
        ##! 16: 'No groups to load'
        return;
    }
    ##! 8: "Requesting transfer for " . join(", ", @aliases)

    # generate our half of the key
    my $priv = Crypt::PK::ECC->new();
    $priv->generate_key('secp256r1');

    my $key_id = substr(sha1_base64($priv->export_key_der('public')), 0, 8);
    ##! 16: "key_id for transfer  $key_id"

    # we store our transfer key as secret
    $self->_set_secret($realm, $key_id, {
        label => 'Cluster Transfer',
        type => 'Plain',
        cache => 'daemon',
        realm => $realm,
        ref => OpenXPKI::Crypto::Secret::Plain->new(part_count => 1),
    });

    # this persists the private key in the secret cache so we can load it later
    $self->set_part({
        GROUP => $key_id,
        VALUE => $priv->export_key_pem('private'),
    });

    # create an item in the secret cache table for each secret we expect
    # group name is key_id (transfer) + secert group name, value is empty
    for my $alias (@aliases) {
        ##! 4: "insert placeholder into database"
        CTX('dbi')->insert(
            into => "secret",
            values  => {
                pki_realm => $realm,
                group_id  => join(":", ($key_id, $alias)),
                data => undef,
            },
        );
    }

    return {
        transfer_id => $key_id,
        pubkey => $priv->export_key_pem('public'),
        groups => \@aliases,
    }
}

=head2 perform_transfer ($pubkey)

Needs to be executed on the sending node, i.e. the one that already has
established/completed its secrets.

Expects the public key created by L</request_transfer> in C<$pubkey> and
tries to fill the database entries assigned to this transfer key.

=cut

sub perform_transfer ($self, $pubkey) {
    ##! 1: "start"

    # create ecc pubkey object for secret sharing
    my $pub = Crypt::PK::ECC->new( \$pubkey );
    my $key_id = substr(sha1_base64($pub->export_key_der('public')), 0, 8);

    my $realm = CTX('session')->data->pki_realm;

    my $db_groups = CTX('dbi')->select_arrays(
        from    => "secret",
        columns => [ 'group_id' ],
        where => {
            pki_realm => $realm,
            group_id  => { -like => "$key_id:%" },
            data => undef,
        }
    );

    ##! 64: $db_groups

    my @aliases = map {  my ($k,$g) = split /:/, $_->[0]; $g; } @{$db_groups};

    # nothing to do
    if (@aliases == 0) {
        return;
    }

    # generate our half of the key
    my $priv = Crypt::PK::ECC->new();
    $priv->generate_key('secp256r1');

    my $vv = OpenXPKI::Crypto::VolatileVault->new({
        TOKEN => $self->default_token,
        KEY => uc(sha256_hex($priv->shared_secret( $pub ))),
        IV => undef
    });
    ##! 32: 'Transfer vault key id id ' . $vv->get_key_id()

    my @transfered;
    my @incomplete;
    # loop though the group list
    for my $alias (@aliases) {
        # if the secret was not unlocked we can not export it
        if (!$self->is_complete($alias)) {
            push @incomplete, $alias;
            next;
        }

        my $def = $self->_get_secret_def($alias)->{_ref}->get_secret();
        CTX('dbi')->update(
            table  => "secret",
            set   => { data => $vv->encrypt( $def ) },
            where => {
                pki_realm => $realm,
                group_id  => "$key_id:$alias",
            }
        );
        push @transfered, $alias;
    }

    return {
        transfer_id => $key_id,
        pubkey => $priv->export_key_pem('public'),
        transfered => \@transfered,
        incomplete => \@incomplete,
    }
}

=head2 accept_transfer ($transfer_id, $pubkey)

Needs to be executed on the receiving node, expects the id and public key
generated by the sending node via L</perform_transfer>.

Transfers the exported secrets from the database (transfer pool) into the
secret cache so they can be used by all children of this node.

=cut

sub accept_transfer ($self, $transfer_id, $pubkey) {
    ##! 1: "start"

    my $realm = CTX('session')->data->pki_realm;

    # pubkey of the sender
    my $pub = Crypt::PK::ECC->new( \$pubkey );

    # in case this is a different child process we need to restore the secret
    # the group id is the transfer_id (=key_id)
    if (not $self->_get_secret_def($transfer_id, 1)) {
        ##! 8: "Restore private key from cache"
        my $cache_type = 'daemon';
        my $secret = OpenXPKI::Crypto::Secret::Plain->new(part_count => 1);
        $secret->thaw($self->_load_from_cache($realm, $transfer_id, $cache_type)); # might be undef
        my $def = {
            label => 'Cluster Transfer',
            type => 'Plain',
            cache => $cache_type,
            realm => $realm,
            _ref => $secret,
            _alias => $transfer_id,
        };
        $self->_set_secret($realm, $transfer_id, $def);
    }
    # load the private key from the secret vault
    my $privkey = $self->_get_secret_def($transfer_id)->{_ref}->get_secret()
        or OpenXPKI::Exception->throw(message => "Unable to restore transfer key");

    my $priv = Crypt::PK::ECC->new( \$privkey );
    # validate if this is the right key
    if (substr(sha1_base64($priv->export_key_der('public')), 0, 8) ne $transfer_id) {
        OpenXPKI::Exception->throw(message => "Transfer id does not match key");
    }

    # create volatile vault using shared secret
    my $vv = OpenXPKI::Crypto::VolatileVault->new({
        TOKEN => $self->default_token,
        KEY => uc(sha256_hex($priv->shared_secret( $pub ))),
        IV => undef
    });

    ##! 32: 'Transfer vault key id id ' . $vv->get_key_id()
    my $db_groups = CTX('dbi')->select_arrays(
        from    => "secret",
        columns => [ 'group_id', 'data' ],
        where => {
            pki_realm => $realm,
            group_id  => { -like => "$transfer_id:%" },
            data => {"!=", undef },
        }
    );

    ##! 64: $db_groups

    # nothing to do
    return unless scalar @{$db_groups};

    my @complete;
    # loop though the group list
    for my $row (@{$db_groups}) {

        my $db_groups = CTX('dbi')->delete(
            from    => "secret",
            where => {
                pki_realm => $realm,
                group_id  => $row->[0],
            }
        );

        ##! 32: $row
        my ($k, $alias) = split /:/, $row->[0];

        # already set - dont touch
        if ($self->is_complete($alias)) {
            ##! 16: "Group $alias is already unlocked - skipping"
            next;
        }

        if (not $vv->can_decrypt( $row->[1] )) {
            ##! 16: "Group $alias was not encrypted with this vault"
            next;
        }

        my $secret = $vv->decrypt( $row->[1] )
            or OpenXPKI::Exception->throw (
                message => "Unable to decrypt secret from transport encryption",
            );

        ##! 8: "Unlock group $alias from transfer"
        $self->set_part({ GROUP => $alias, VALUE => $secret });
        push @complete, $alias;
    }

    return {
        transfer_id => $transfer_id,
        complete => \@complete,
    };
}

__PACKAGE__->meta->make_immutable;
