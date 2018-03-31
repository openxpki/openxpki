package OpenXPKI::Server::API2::Plugin::Datapool::set_data_pool_entry;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::set_data_pool_entry

=cut

# Project modules
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
    expiration_date => { isa => 'Int', },
    force           => { isa => 'Bool', default => 0 },
    encrypt         => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my $requested_pki_realm = $params->pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);

    my @caller = $self->rawapi->my_caller;
    if ($caller[0] =~ m{ \A OpenXPKI::Server::Workflow }xms and $params->namespace =~ m{ \A sys\. }xms) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_NAMESPACE',
            params => { namespace => $params->namespace, },
        );

    }

    # forward encryption request to the worker function, use symmetric
    # encryption
    my $encrypt = $params->encrypt ? 'current_symmetric_key' : undef;

    # erase expired entries
    $self->cleanup;
    $self->set_entry({
        key         => $params->key,
        value       => $params->value,
        namespace   => $params->namespace,
        pki_realm   => $requested_pki_realm,
        force       => $params->force,
        $params->has_expiration_date ? (expiration_date => $params->expiration_date) : (),
        $params->encrypt ? (encrypt => 'current_symmetric_key') : (),
    });
    return 1;
};

__PACKAGE__->meta->make_immutable;
