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

Writes the specified information to the global data pool, possibly encrypting
the value using the password safe defined for the PKI Realm.

Named parameters:

=over

=item * PKI_REALM - PKI Realm to address. If the API is called directly
  from OpenXPKI::Server::Workflow only the PKI Realm of the currently active
  session is accepted. If no realm is passed, the current realm is used.

=item * NAMESPACE

=item * KEY

=item * VALUE - Value to store

=item * ENCRYPTED - optional, set to 1 if you wish the entry to be encrypted. Requires a properly set up password safe certificate in the target realm.

=item * FORCE - optional, set to 1 in order to force writing entry to database

=item * EXPIRATION_DATE

optional, seconds since epoch. If current time passes this date the server will
delete the entry. Default is to keep the value for infinity.

If you call C<set_data_pool_entry> with the C<FORCE> option to update an
existing value, the (new) expiry date must be passed again or will be reset to
inifity!

To prevent unwanted deletion, a value of C<0> is not accepted.

=back

Side effect: this method automatically wipes all data pool entries whose
expiration date has passed.

B<NOTE:> Encryption may work even though the private key for the password safe
is not available (the symmetric encryption key is encrypted for the password
safe certificate). Retrieving encrypted information will only work if the
password safe key is available during the first access to the symmetric key.


Example:

    CTX('api')->set_data_pool_entry( {
        PKI_REALM => $pki_realm,
        NAMESPACE => 'workflow.foo.bar',
        KEY => 'myvariable',
        VALUE => $tmpval,
        ENCRYPT => 1,
        FORCE => 1,
        EXPIRATION_DATE => time + 3600 * 24 * 7,
    } );

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "set_data_pool_entry" => {
    namespace       => { isa => 'AlphaPunct', required => 1, },
    key             => { isa => 'AlphaPunct', required => 1, },
    pki_realm       => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
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
