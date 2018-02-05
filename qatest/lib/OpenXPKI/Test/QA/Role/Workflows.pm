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
use OpenXPKI::Test::QA::Role::Workflows::CertParams;
use OpenXPKI::Serialization::Simple;


requires 'also_init';


has _workflow_id => (
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
);


before 'init_server' => sub {
    my $self = shift;
    # prepend to existing array in case a user supplied "also_init" needs our modules
    unshift @{ $self->also_init }, 'workflow_factory';
};

=head1 METHODS

This role adds the following methods to L<OpenXPKI::Test>:

=cut

=head2 create_workflow_instance

Creates a workflow by calling API command I<create_workflow_instance> and stores
the workflow's ID in object attribute I<_workflow_id>.

Returns the workflow ID.

B<Positional Parameters>

=over

=item * C<$workflow> I<Str> - workflow name / identifier

=item * C<$params> I<HashRef> - workflow parameters

=back

=cut
sub create_workflow_instance {
    my ($self, $workflow, $params) = @_;

    my $result = $self->api_command(
        create_workflow_instance => {
            WORKFLOW => $workflow,
            PARAMS => $params,
        }
    );
    my $id = $result->{WORKFLOW}->{ID} or die explain $result;

    note "Created workflow #$id";
    $self->_workflow_id($id);

    return $id;
}

=head2 wf_activity

Executes the API command I<execute_workflow_activity>.

Currently only used internally by test classes. Please note that the object
attribute I<_workflow_id> must be set before this method can be used.

Example:

    $oxitest->wf_activity(
        'ENTER_KEY_PASSWORD',
        csr_ask_client_password,
        { _password => "m4#bDf7m3abd" },
    );

B<Positional Parameters>

=over

=item * C<$expected_state> I<Str> - expected current workflow state

=item * C<$activity> I<Str> - workflow activity name

=item * C<$params> I<HashRef> - parameters

=back

=cut
sub wf_activity {
    my ($self, $expected_state, $activity, $params) = @_;

    if ($expected_state) {
        die "workflow state is not '$expected_state'" unless $self->wf_is_state($expected_state);
    }

    return $self->api_command(
        execute_workflow_activity => {
            ID => $self->_workflow_id,
            ACTIVITY => $activity,
            PARAMS => $params,
        }
    );
}

=head2 wf_is_state

Checks if the state of the workflow currently referenced by I<_workflow_id>.

This command only works if the workflow has previously been modified by (
directly or indirectly) using L<OpenXPKI::Test/api_command>.

B<Positional Parameters>

=over

=item * C<$expected_state> I<Str> - expected current workflow state

=back

=cut
sub wf_is_state {
    my ($self, $expected_state) = @_;
    return ($self->_last_api_result->{WORKFLOW}->{STATE} eq $expected_state);
}

1;
