package OpenXPKI::Server::API2::Plugin::Datapool::clear_data_pool_namespace;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::clear_data_pool_namespace

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head1 COMMANDS

=head2 delete_data_pool_entry

Removes all entries in a given namespace, does not check if the namespace
has items and always returns true.

Side effect: this method automatically wipes all data pool entries whose
expiration date has passed.

Example:

    CTX('api2')->clear_data_pool_namespace(
        pki_realm => $pki_realm,
        namespace => 'workflow.foo.bar',
    );

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

If the API is called directly from OpenXPKI::Server::Workflow only the PKI realm
of the currently active session is accepted.

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=back

=cut
command "clear_data_pool_namespace" => {
    pki_realm       => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace       => { isa => 'AlphaPunct', required => 1, },
} => sub {

    my ($self, $params) = @_;
    ##! 8: "Cleanup datapool namespace: realm=".$params->pki_realm.", namespace=".$params->namespace

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

    CTX('dbi')->delete(
        from => 'datapool',
        where => {
            namespace => $params->namespace,
            pki_realm => $requested_pki_realm,
        }
    );
    # erase expired entries
    $self->cleanup;
    return 1;
};

__PACKAGE__->meta->make_immutable;
