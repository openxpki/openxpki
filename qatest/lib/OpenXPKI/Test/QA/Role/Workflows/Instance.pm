package OpenXPKI::Test::QA::Role::Workflows::Instance;
use Moose;
use utf8;

# Core modules
use Test::More;
use Test::Exception;

# Project modules
use OpenXPKI::Server::Context;

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
L<create_workflow_instance|OpenXPKI::Server::API2::Plugin::Workflow::create_workflow_instance>
or fetches an existing workflow's state.

Named parameters:

=over

=item * C<oxitest> I<OpenXPKI::Test> - instance of the test object

=item * C<type> I<Str> - new workflow: workflow type (i.e. name)

=item * C<params> I<HashRef> - new workflow: workflow parameters. Default: {}

=item * C<id> I<Str> - existing workflow: ID

=back

=cut

has oxitest => (
    is => 'rw',
    isa => 'OpenXPKI::Test',
);

has type => (
    is => 'rw',
    isa => 'Str',
);

has params => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

has id => (
    is => 'rw',
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

    die "Please specify either 'type' (to create a new workflow) or 'id' (fetch existing one)"
        unless $self->id || $self->type;

    # new workflow
    if ($self->type) {
        my $data = $self->oxitest->api2_command(
            create_workflow_instance => { workflow => $self->type, params => $self->params }
        );
        my $id = $data->{workflow}->{id} or die explain $data;
        $self->id($id);
        $self->last_wf_state($data->{workflow}) if $data->{workflow};
        note "Created workflow #$id (".$self->type.")";
    }
    # existing workflow
    else {
        $self->metadata;
        my $type = $self->last_wf_state->{type} or die explain $self->last_wf_state;
        $self->type($type);
        note "Fetched workflow #".$self->id." ($type)";
    }
}

=head2 metadata

Queries the API for the current workflow metadata and returns it (I<HashRef>).

=cut
sub metadata {
    my ($self) = @_;
    my $data = $self->oxitest->api2_command(
        get_workflow_info => { id => $self->id }
    );
    $self->last_wf_state($data->{workflow}) if $data->{workflow};
    return $data;
}

=head2 state

Returns the current workflow state. Please use L</metadata> to get all current
workflow informations.

=cut
sub state {
    my $self = shift;
    return $self->last_wf_state->{state};
}

=head2 execute

Executes the API command I<execute_workflow_activity> as a test.

Example:

    $wf->execute(
        "csr_ask_client_password",
        { _password => "m4#bDf7m3abd" },
    );

B<Positional Parameters>

=over

=item * C<$activity> I<Str> - workflow activity name

=item * C<$params> I<HashRef> - parameters

=back

=cut
sub execute {
    my ($self, $activity, $params) = @_;

    my $result;
    lives_ok {
        $result = $self->oxitest->api2_command(
            execute_workflow_activity => {
                id => $self->id,
                activity => $activity,
                params => $params // {},
            }
        );
        $self->last_wf_state($result->{workflow}) if $result->{workflow};
    } "Executing workflow activity $activity";

    return $result;
}

=head2 execute_fails

Executes the API command I<execute_workflow_activity> as a test and expect
it to fail with the given exception.

Example:

    $wf->execute_fails(
        "csr_ask_client_password",
        { _password => "m4#bDf7m3abd" },
        qr/MyException/,
    );

B<Positional Parameters>

=over

=item * C<$activity> I<Str> - workflow activity name

=item * C<$params> I<HashRef> - parameters

=item * C<$failure> I<Regex> - Regular expression that the exceptions is matched agains

=back

=cut
sub execute_fails {
    my ($self, $activity, $params, $failure) = @_;

    my $result;
    throws_ok {
        $self->oxitest->api2_command(
            execute_workflow_activity => {
                id => $self->id,
                activity => $activity,
                params => $params // {},
            }
        );
    } $failure, "Executing workflow activity $activity should fail";
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
    is $self->state, $expected_state, "workflow state is '$expected_state'";
}

__PACKAGE__->meta->make_immutable;
