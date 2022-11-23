package OpenXPKI::Server::API2::Plugin::Datapool::delete_data_pool_entry;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::delete_data_pool_entry

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head1 COMMANDS

=head2 delete_data_pool_entry

Delete an entry, specified by namespace and key, from the datapool. The
command does not check if the entry exists at all and always returns true.

Side effect: this method automatically wipes all data pool entries whose
expiration date has passed.

Example:

    CTX('api2')->delete_data_pool_entry(
        pki_realm => $pki_realm,
        namespace => 'workflow.foo.bar',
        key => 'myvariable',
    );

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

If the API is called directly from OpenXPKI::Server::Workflow only the PKI realm
of the currently active session is accepted.

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=item * C<key> I<Str> - entry key

=back

=cut
command "delete_data_pool_entry" => {
    pki_realm       => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace       => { isa => 'AlphaPunct', required => 1, },
    key             => { isa => 'AlphaPunct|Email', required => 1, },
} => sub {

    my ($self, $params) = @_;
    ##! 8: "Writing datapool entry: realm=".$params->pki_realm.", namespace=".$params->namespace.", key=".$params->key

    my $requested_pki_realm = $params->pki_realm;

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

    # erase expired entries
    $self->cleanup;
    $self->set_entry(  # from ::Util
        key         => $params->key,
        value       => undef,
        namespace   => $params->namespace,
        pki_realm   => $requested_pki_realm,
    );
    return 1;
};

__PACKAGE__->meta->make_immutable;
