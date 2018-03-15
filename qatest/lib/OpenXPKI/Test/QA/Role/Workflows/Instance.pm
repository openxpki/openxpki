package OpenXPKI::Test::QA::Role::Workflows::Instance;
use Moose;
use utf8;

# Core modules
use Test::More;

=head1 NAME

OpenXPKI::Test::QA::Role::Workflows::Instance - represents an instance
of a workflow that can be tested

=head1 METHODS

=cut

################################################################################
# Constructor attributes
#

=head2 new

Constructor: creates a new workflow instance using API command
L<create_workflow_instance|OpenXPKI::Server::API2::Plugin::Workflow::create_workflow_instance>.

Named parameters:

=over

=item * C<oxitest> I<OpenXPKI::Test> - instance of the test object

=item * C<type> I<Str> - workflow type (i.e. name)

=item * C<params> I<HashRef> - workflow parameters. Default: {}

=back

=cut

has oxitest => (
    is => 'rw',
    isa => 'OpenXPKI::Test',
    required => 1,
);

has type => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has params => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

=head2 id

Returns the workflow ID.

=cut
has id => (
    is => 'rw',
    init_arg => undef,
);

=head2 last_wf_state

Returns the workflow status I<HashRef> as returned by the last execution of the
C<execute_workflow_activity> API command.

=cut
has last_wf_state => (
    is => 'rw',
    isa => 'Any',
    init_arg => undef,
    predicate => 'has_last_wf_state',
);

#
#
#
sub BUILD {
    my $self = shift;

    my $data = $self->oxitest->api_command(
        create_workflow_instance => {
            WORKFLOW => $self->type,
            PARAMS => $self->params,
        }
    );
    $self->last_wf_state($data->{WORKFLOW}) if $data->{WORKFLOW};

    my $id = $data->{WORKFLOW}->{ID} or die explain $data;
    $self->id($id);
    note "Created workflow #$id";
}

=head2 start_activity

Executes the API command I<execute_workflow_activity>.

Example:

    $wf->start_activity(
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
sub start_activity {
    my ($self, $expected_state, $activity, $params) = @_;

    if ($expected_state) {
        $self->state_is($expected_state) or die "unexpected workflow state";
    }

    my $result = $self->oxitest->api_command(
        execute_workflow_activity => {
            ID => $self->id,
            ACTIVITY => $activity,
            PARAMS => $params,
        }
    );
    $self->last_wf_state($result->{WORKFLOW}) if $result->{WORKFLOW};
    return $result;
}

=head2 state_is

Checks the state of the workflow (with a L<Test::More> test).

This command only works if the workflow has previously been modified by this
classes methods.

B<Positional Parameters>

=over

=item * C<$expected_state> I<Str> - expected current workflow state

=back

=cut
sub state_is {
    my ($self, $expected_state) = @_;
    if ($self->has_last_wf_state) {
        is $self->last_wf_state->{STATE}, $expected_state, "workflow state is '$expected_state'";
    }
    else {
        fail "workflow state is '$expected_state'";
    }
}

__PACKAGE__->meta->make_immutable;
