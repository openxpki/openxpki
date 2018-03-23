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

=back

=cut
sub create_workflow {
    my ($self, $type, $params) = @_;

    return OpenXPKI::Test::QA::Role::Workflows::Instance->new(
        oxitest => $self,
        type => $type,
        $params ? (params => $params) : (),
    );
}

1;
