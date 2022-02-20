package OpenXPKI::Server::API2::Plugin::Datapool::set_data_pool_entry;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::set_data_pool_entry

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 set_data_pool_entry

Writes the specified entry (key-value pair) to the global data pool, possibly
encrypting the value using the password safe defined for the PKI Realm.

Side effect: this method automatically wipes all data pool entries whose
expiration date has passed.

B<NOTE:> Encryption may work even though the private key for the password safe
is not available (the symmetric encryption key is encrypted for the password
safe certificate). Retrieving encrypted information will only work if the
password safe key is available during the first access to the symmetric key.


Example:

    CTX('api2')->set_data_pool_entry(
        pki_realm => $pki_realm,
        namespace => 'workflow.foo.bar',
        key => 'myvariable',
        value => $tmpval,
        encrypt => 1,
        force => 1,
        expiration_date => time + 3600 * 24 * 7,
    );

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

If the API is called directly from OpenXPKI::Server::Workflow only the PKI realm
of the currently active session is accepted.

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=item * C<key> I<Str> - entry key

=item * C<value> I<Str> - entry value to store

=item * C<expiration_date> I<Int> - UNIX epoch timestamp when the entry shall be
deleted. Optional, default: keep entry infinitely.

To prevent unwanted deletion, a value of C<0> is not accepted.

=item * C<force> I<Bool> - set to 1 to enforce overwriting a possibly existing
entry.

If set, the (new) C<expiration_date> must be passed again or will be reset to
inifity!

=item * C<encrypt> I<Bool> - set to 1 if you wish the entry to be encrypted.
Optional, default: 0

Requires a properly set up password safe certificate in the target realm.

=back

=cut
command "set_data_pool_entry" => {
    pki_realm       => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace       => { isa => 'AlphaPunct', required => 1, },
    key             => { isa => 'AlphaPunct', required => 1, },
    value           => { isa => 'Str', required => 1, },
    expiration_date => { isa => 'Int', matching => sub { $_ > time }, },
    force           => { isa => 'Bool', default => 0 },
    encrypt         => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;
    ##! 8: "Writing datapool entry: realm=".$params->pki_realm.", namespace=".$params->namespace.", key=".$params->key

    if ($params->value eq '') {
        CTX('log')->system()->warn("Implicit delete via set_data_pool_entry with empty value is deprecated - use delete_data_pool_entry instead!");
    }

    my $requested_pki_realm = $params->pki_realm;

    # check for illegal characters - not neccesary if we encrypt the value
    OpenXPKI::Exception->throw(
        message => "Value contains illegel characters",
        params => { pki_realm => $params->pki_realm, namespace => $params->namespace, key => $params->key }
    ) if !$params->has_encrypt and ($params->value =~ m{ (?:\p{Unassigned}|\x00) }xms );

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);

    ##! 32: "checking if caller is workflow class that tries to access sys.* namespace"
    my @caller = $self->rawapi->my_caller;
    if ($caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms and $params->namespace =~ m{ \A sys\. }xms) {
        OpenXPKI::Exception->throw(
            message => 'Access to namespace sys.* not allowed when called from OpenXPKI::Server::Workflow::*',
            params => { namespace => $params->namespace, },
        );

    }

    my $value;
    my $encryption_key_id;
    # plain value
    if (not $params->encrypt) {
        ##! 16: "plain text value"
        $value = $params->value;
    }
    # symmetric encryption
    else {
        my $enc_key = $self->get_realm_encryption_key( CTX('session')->data->pki_realm ); # from ::Util
        ##! 16: "symmetrically encrypted value: setting up volatile vault (".join(", ", map { "$_=".($enc_key->{$_} // '<undef>') } sort keys %$enc_key).")"
        my $vault = OpenXPKI::Crypto::VolatileVault->new({
            %{$enc_key},
            TOKEN => $self->api->get_default_token,
        });
        $value = $vault->encrypt($params->value);
        $encryption_key_id = $enc_key->{KEY_ID};
    }

    # erase expired entries
    $self->cleanup;
    $self->set_entry(  # from ::Util
        key         => $params->key,
        value       => $value,
        namespace   => $params->namespace,
        pki_realm   => $requested_pki_realm,
        force       => $params->force,
        enc_key_id  => $encryption_key_id,
        $params->has_expiration_date ? (expiration_date => $params->expiration_date) : (),
    );
    return 1;
};

__PACKAGE__->meta->make_immutable;
