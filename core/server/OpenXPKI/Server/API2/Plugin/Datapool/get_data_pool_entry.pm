package OpenXPKI::Server::API2::Plugin::Datapool::get_data_pool_entry;
use OpenXPKI -plugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::get_data_pool_entry

=cut

# Core modules

# CPAN modules

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;

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

Returns undef if no item is found.

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

If the API is called directly from OpenXPKI::Server::Workflow only the PKI realm
of the currently active session is accepted.

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=item * C<key> I<Str> - entry key

=item * C<decrypt> I<Bool> - set to 0 to skip decryption of encrypted items

=item * C<deserialize> L<SerializationFormat|OpenXPKI::Types/SerializationFormat> - deserialization format for complex values. Optional

=item * C<try_deserialize> L<SerializationFormat|OpenXPKI::Types/SerializationFormat> - like C<deserialize> but returns C<undef> instead of throwing an exception if deserialization fails. Optional

=back

=cut

command "get_data_pool_entry" => {
    pki_realm => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace => { isa => 'AlphaPunct', required => 1, },
    # TODO Change type of "key" back to "AlphaPunct" once we have a private method to get encrypted data pool entries (where keys have more characters)
    key       => { isa => 'Str|Email', required => 1, },
    decrypt   => { isa => 'Bool', default => 1 },
    deserialize => { isa => 'SerializationFormat' },
    try_deserialize => { isa => 'SerializationFormat' },
} => sub {
    my ($self, $params) = @_;
    ##! 8: "Reading datapool entry: realm=".$params->pki_realm.", namespace=".$params->namespace.", key=".$params->key

    my $namespace = $params->namespace;
    my $key       = $params->key;
    my $realm     = $params->pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($realm); # from ::Util

    my $result = $self->get_entry($realm, $namespace, $key); # from ::Util
    ##! 64: "Database result: ".Dumper($result)

    # no entry found, do not raise exception but simply return undef
    if (not $result) {
        CTX('log')->system->debug("Data pool entry '$key' not found");
        return;
    }

    my $value = $result->{datapool_value};

    # decryption
    if (($params->decrypt) && (my $encryption_key = $result->{encryption_key})) {
        # internal passwordsafe key encrypted with a main key
        if (my ($safe_id) = $encryption_key =~ m{ \A \w+:(.*) }xms ) {
            ##! 16: "Datapool decryption for key $encryption_key)"
            $value = $self->decrypt_passwordsafe($safe_id, $value); # from ::Util
        }
        # symmetric decryption
        else {
            ##! 16: "Symmetric decryption (key = $encryption_key)"
            $value = $self->_decrypt_symmetric($realm, $encryption_key, $value);
        }
    }

    # deserialization
    my $ser;
    $ser = $params->deserialize if $params->has_deserialize;
    $ser = $params->try_deserialize if $params->has_try_deserialize;

    if ($ser) {
        ##! 16: "deserialization with format '$ser'"
        if ('simple' eq $ser) {
            try {
                $value = OpenXPKI::Serialization::Simple->new->deserialize($value);
            }
            catch ($err) {
                # fail unless "try_deserialize" was specified
                if (not $params->has_try_deserialize) {
                    OpenXPKI::Exception->throw(
                        message => "Could not deserialize Datapool value: $err",
                        params => { pki_realm => $params->pki_realm, namespace => $params->namespace, key => $params->key }
                    );
                }
            }
        }
    }

    return {
        pki_realm => $result->{pki_realm},
        namespace => $result->{namespace},
        key       => $result->{datapool_key},
        mtime     => $result->{last_update},
        value     => $value,
        encrypted => ($result->{encryption_key} ? 1 : 0),
        $result->{encryption_key}
            ? ( encryption_key => $result->{encryption_key} ) : (),
        $result->{notafter}
            ? ( expiration_date => $result->{notafter} ) : (),
    };
};

# Symmetric decryption using the given key ID
sub _decrypt_symmetric {
    my ($self, $realm, $enc_key_id, $enc_value) = @_;

    my $keyinfo = $self->fetch_symmetric_key($realm, $enc_key_id); # from ::Util role

    ##! 16: 'setting up volatile vault for symmetric decryption'
    my $vault = OpenXPKI::Crypto::VolatileVault->new({
        ALGORITHM => $keyinfo->{alg},
        KEY       => $keyinfo->{key},
        IV        => $keyinfo->{iv},
        TOKEN     => $self->api->get_default_token,
    });

    return $vault->decrypt($enc_value);
}

__PACKAGE__->meta->make_immutable;
