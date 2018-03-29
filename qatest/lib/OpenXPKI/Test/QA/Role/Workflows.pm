package OpenXPKI::Test::QA::Role::Workflows;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::QA::Role::Workflows - Moose role that extends L<OpenXPKI::Test>
for workflow execution.

=cut

# CPAN modules
use Test::More;
use Test::Exception;

# Project modules
use OpenXPKI::Server::Context;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Test::QA::Role::Workflows::CertParams;
use OpenXPKI::Test::QA::Role::Workflows::Instance;
use OpenXPKI::Test::QA::Role::Workflows::InstanceOldApi;


requires 'also_init';


before 'init_server' => sub {
    my $self = shift;
    # prepend to existing array in case a user supplied "also_init" needs our modules
    unshift @{ $self->also_init }, 'workflow_factory';
};

=head1 METHODS

This role adds the following methods to L<OpenXPKI::Test>:

=cut

=head2 create_workflow

Creates and returns a workflow instance wrapped in
L<OpenXPKI::Test::QA::Role::Workflows::Instance> which can be used for
further tests.

B<Positional Parameters>

=over

=item * C<$type> I<Str> - workflow name / type

=item * C<$params> I<HashRef> - workflow parameters. Optional.

=item * C<$old_api> I<Bool> - set to 1 to use old API for workflow management

=back

=cut
sub create_workflow {
    my ($self, $type, $params, $old_api) = @_;

    if ($old_api) {
        return OpenXPKI::Test::QA::Role::Workflows::InstanceOldApi->new(
            oxitest => $self,
            type => $type,
            $params ? (params => $params) : (),
        );
    }
    else {
        return OpenXPKI::Test::QA::Role::Workflows::Instance->new(
            oxitest => $self,
            type => $type,
            $params ? (params => $params) : (),
        );
    }
}

=head2 fetch_workflow

Fetches an existing workflow instance wrapped in
L<OpenXPKI::Test::QA::Role::Workflows::Instance> which can be used for
further tests.

B<Positional Parameters>

=over

=item * C<$id> I<Str> - workflow ID

=item * C<$old_api> I<Bool> - set to 1 to use old API for workflow management

=back

=cut
sub fetch_workflow {
    my ($self, $id, $old_api) = @_;

    if ($old_api) {
        return OpenXPKI::Test::QA::Role::Workflows::InstanceOldApi->new(
            oxitest => $self,
            id => $id,
        );
    }
    else {
        return OpenXPKI::Test::QA::Role::Workflows::Instance->new(
            oxitest => $self,
            id => $id,
        );
    }
}

1;
