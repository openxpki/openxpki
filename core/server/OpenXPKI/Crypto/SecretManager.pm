package OpenXPKI::Crypto::SecretManager;
use Moose;

# Core modules
use Digest::SHA qw(sha256_hex sha1_base64);

# CPAN modules
use Crypt::Argon2;
use Crypt::PK::ECC;
use Template;
use Try::Tiny;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Control;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::FileUtils;

=head1 NAME

OpenXPKI::Crypto::SecretManager

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

When called first this method tries to load the secret data from configuration
and (the serialized data) from the cache.

=cut

sub _get_secret_def {
    my ($self, $alias, $return_undef_if_not_found) = @_;
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
        ##! 16: "query definition '$realm.crypto.secr_t.$alias'"
        $def = $self->_load(['crypto', 'secret'], $realm, $alias);

        # Handle imports (i.e. references to global definition)
        if (defined $def and $def->{import}) {
            ##! 16: "'import' statement - query definition 'system.crypto.secr_t.$alias"
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

=head2 _set_secret ($realm, $group, $secret_def)

Set the named secret to the given C<$secret_def> I<HashRef>.

=cut

sub _set_secret {
    my ($self, $realm, $group, $secret_def) = @_;

    $self->secrets->{$realm} //= {};
    $self->secrets->{$realm}->{$group} = $secret_def;
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

sub _load {
    my ($self, $confpath, $realm, $alias) = @_;
    ##! 1: "start: alias '$realm.$alias'"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_LOAD_SECRET_MISSING_GROUP"
    ) unless $alias;

    my $def = CTX('config')->get_hash([ @{ $confpath }, $alias ]);

    return unless $def;
    return $def if $def->{import}; # stop processing as we'll throw away this hash if a global secret is referenced

    $def->{cache} = "none" if ($def->{method} // "") eq "literal"; # force "no cache" for literal secrets
    $def->{_alias} = $alias;
    $def->{_realm} = $realm;

    ##! 2: "initialize object"
    my $secret = $self->_create_object($def);
    ##! 2: "load serialized data into object (if any)"
    $secret->thaw($self->_load_from_cache($realm, $alias, $def->{cache})); # might be undef
    $def->{_ref} = $secret;

    ##! 1: "finish"
    return $def;
}

=head2 _create_object ($secret_def)

Returns an object with Moose role L<OpenXPKI::Crypto::SecretRole> according to
the given config data I<HashRef>.

=cut

sub _create_object {
    my ($self, $secret_def) = @_;

    my $realm = $secret_def->{_realm};
    my $method = lc($secret_def->{method} || "");
    my $share_type = lc($secret_def->{share_type} || "plain");
    my $share_store = lc($secret_def->{share_store} || "");
    my $group = $secret_def->{_alias};

    if ('literal' eq $method) {
        require OpenXPKI::Crypto::Secret::Plain;
        my $secret = OpenXPKI::Crypto::Secret::Plain->new(
            part_count => 1,
        );
        $secret->set_secret($secret_def->{value});
        return $secret;
    }
    elsif ('plain' eq $method) {
        require OpenXPKI::Crypto::Secret::Plain;
        return OpenXPKI::Crypto::Secret::Plain->new(
            part_count => ($secret_def->{total_shares} || 1),
        );
    }
    elsif ('split' eq $method) {
        my %split_secret_args = (
            quorum_k => $secret_def->{required_shares},
            quorum_n => $secret_def->{total_shares},
            token  => $self->default_token,
        );

        if ('plain' eq $share_type) {
            require OpenXPKI::Crypto::Secret::Split;
            return OpenXPKI::Crypto::Secret::Split->new(%split_secret_args);
        }
        elsif ('encrypted' eq $share_type) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_SHARE_STORE_MISSING"
            ) unless $secret_def->{share_store};

            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_INIT_SECRET_SHARE_NAME_MISSING"
            ) unless $secret_def->{share_name};

            # set up filesystem or datapool backend (loader)
            my $loader;
            if ('filesystem' eq $share_store) {
                $loader = sub {
                    my ($share_name) = @_;
                    ##! 16: "loading encrypted share from filesystem: $share_name"
                    my $share;
                    try {
                        $share = OpenXPKI::FileUtils->read_file($share_name);
                    } catch {
                        CTX('log')->application->warn("Could not open encrypted share: $_");
                    };
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
                    $secret_def->{share_name},
                    $group,
                    $secret_def->{total_shares}
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

sub _get_encryptedshare_names {
    my ($self, $template, $alias, $count) = @_;
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

sub _load_from_cache {
    my ($self, $realm, $alias, $cache_type) = @_;

    $cache_type = lc($cache_type || "");

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
        message => "Unsupported cache type",
        params  => { TYPE => $cache_type, GROUP => $alias }
    );
}

=head2 _save_to_cache ($realm, $alias, $cache_type, $dump)

Save the secret's serialized data to the cache (session or DB).

=cut

sub _save_to_cache {
    my ($self, $realm, $alias, $cache_type, $dump) = @_;

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

=head2 _clear_cache ($secret_def)

Removes the secret's serialized data from the cache (session or DB).

=cut

sub _clear_cache {
    my ($self, $secret_def) = @_;

    my $cache_type = lc($secret_def->{cache} || "");
    my $realm = $secret_def->{_realm};
    my $alias = $secret_def->{_alias};

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
        OpenXPKI::Control::reload();
    }
    else {
        OpenXPKI::Exception->throw (
            message => "Unsupported cache type",
            params  => { TYPE => $cache_type, GROUP => $alias }
        );
    }
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

sub get_infos {
    ##! 1: "start"
    my $self = shift;

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
    ##! 2: "build list"
    for my $alias (@name_list) {
        ##! 16: "$alias"
        my $def = $self->_get_secret_def($alias)
            or OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CRYPTO_SECRETMANAGER_GET_SECRET_GROUPS_GROUP_NOT_FOUND",
                params => { GROUP => $alias },
            );
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

sub get_required_part_count {
    my ($self, $alias) = @_;
    my $def = $self->_get_secret_def($alias);
    return $def->{_ref}->required_part_count;
}

=head2 get_inserted_part_count

Returns the number of parts that are already inserted / set.

=cut

sub get_inserted_part_count {
    my ($self, $alias) = @_;
    my $def = $self->_get_secret_def($alias);
    return $def->{_ref}->inserted_part_count;
}

=head2 is_complete ($alias)

Check if the secret is complete (all passwords loaded).

Returns C<0> or C<1>.

=cut

sub is_complete {
    my ($self, $alias) = @_;
    ##! 1: "start"
    return $self->_get_secret_def($alias)->{_ref}->is_complete ? 1 : 0;
}

=head2 get_secret ($alias)

Get the plaintext value of the stored secret. This requires that the
secret was created with the "export" flag set, otherwise an exception
is thrown.

Returns the secret value or C<undef> if the secret is not complete.

=cut

sub get_secret {
    my ($self, $alias) = @_;
    ##! 1: "start"

    return undef unless $self->is_complete($alias);

    my $secret_def = $self->_get_secret_def($alias);

    if (not $secret_def->{export}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_SECRET_GROUP_NOT_EXPORTABLE"
        );
    }

    return $secret_def->{_ref}->get_secret();
}

=head2 set_part ({ GROUP, VALUE, PART })

Set the secret C<VALUE> of the given C<GROUP> (aka alias), for plain secrets
omit C<PART>.

=cut

sub set_part {
    my ($self, $args) = @_;
    ##! 1: "start"
    my $alias = $args->{GROUP};
    my $part  = $args->{PART};
    my $value = $args->{VALUE};

    ##! 2: "init"
    my $def = $self->_get_secret_def($alias);
    my $obj = $def->{_ref};

    # store in case we need to restore on failure
    my $old_secret = $obj->freeze;

    ##! 2: "setting $alias" . (defined $part ? ", part $part" : "")
    $obj->set_secret($value, $part); # $part might be undef

    if ($def->{kcv} and $obj->is_complete) {
        my $password = $obj->get_secret;
        if (!Crypt::Argon2::argon2id_verify($def->{kcv}, $password)) {
            $obj->thaw($old_secret);
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_UI_SECRET_UNLOCK_KCV_MISMATCH",
            );
        }
    }

    $self->_save_to_cache($def->{_realm}, $alias, $def->{cache}, $obj->freeze);
    ##! 1: "finished"
}

=head2 clear ($alias)

Purge the secret of the given name.

=cut

sub clear {
    my ($self, $alias) = @_;
    ##! 1: "start"

    ##! 2: "init"
    my $secret_def = $self->_get_secret_def($alias);

    $self->_clear_cache($secret_def);

    # Clear secret data (makes it unset/incomplete again)
    $secret_def->{_ref}->clear_secret;

    ##! 1: "finished"
}

=head2 request_transfer

Initialize a secret transfer to the current node. Creates a keypair for
negotiation of the transfer secret and writes placeholder items for this key
into the database.

=cut

sub request_transfer {
    my $self = shift;
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

sub perform_transfer {
    my ($self, $pubkey) = @_;
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

sub accept_transfer {
    my ($self, $transfer_id, $pubkey) = @_;
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
        my $secret_def = {
            label => 'Cluster Transfer',
            type => 'Plain',
            cache => $cache_type,
            realm => $realm,
            _ref => $secret,
            _alias => $transfer_id,
        };
        $self->_set_secret($realm, $transfer_id, $secret_def);
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
