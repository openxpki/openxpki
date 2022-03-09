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


#
# Attributes
#
has 'managed_workflows' => (
    is => "rw",
    isa => "HashRef[Int]",
    init_arg => undef,
    default => sub { {} },
);

#
# Modified methods
#
before 'init_server' => sub {
    my $self = shift;
    # prepend to existing array in case a user supplied "also_init" needs our modules
    unshift @{ $self->also_init }, 'workflow_factory';
};

after 'set_user' => sub {
    my $self = shift;
    # reset condition cache so e.g. user role checks are re-evaluated
    for my $id (keys %{ $self->managed_workflows }) {
        OpenXPKI::Server::Context::CTX('workflow_factory')
            ->get_factory
            ->fetch_workflow($self->managed_workflows->{$id}, $id)
            ->_get_workflow_state
            ->clear_condition_cache;
    }
};

=head1 METHODS

This role adds the following methods to L<OpenXPKI::Test>:

=cut

=head2 create_workflow_ok

Creates and returns a workflow instance wrapped in
L<OpenXPKI::Test::QA::Role::Workflows::Instance> which can be used for
further tests.

B<Positional Parameters>

=over

=item * C<$type> I<Str> - workflow name / type

=item * C<$params> I<HashRef> - workflow parameters. Optional.

=back

=cut
sub create_workflow_ok {
    my ($self, $type, $params) = @_;

    my $wf = OpenXPKI::Test::QA::Role::Workflows::Instance->new(
        oxitest => $self,
        type => $type,
        $params ? (params => $params) : (),
    );
    $self->managed_workflows->{$wf->id} = $wf->type;
    return $wf;
}

=head2 fetch_workflow

Fetches an existing workflow instance wrapped in
L<OpenXPKI::Test::QA::Role::Workflows::Instance> which can be used for
further tests.

B<Positional Parameters>

=over

=item * C<$id> I<Str> - workflow ID

=back

=cut
sub fetch_workflow {
    my ($self, $id) = @_;

    my $wf = OpenXPKI::Test::QA::Role::Workflows::Instance->new(
        oxitest => $self,
        id => $id,
    );
    $self->managed_workflows->{$wf->id} = $wf->type;
    return $wf;
}

sub wait_for_proc_state {
    my ($self, $wfid, $state_regex) = @_;

    my $result;
    my $count = 0;
    while ($count++ < 20) {
        $result = OpenXPKI::Server::Context::CTX('api2')->search_workflow_instances(id => [ $wfid ]);
        # no workflow found?
        if (not scalar @$result or $result->[0]->{'workflow_id'} != $wfid) {
            die("Workflow with ID $wfid not found");
        }
        # wait if paused (i.e. resuming in progress) or still running (the remaining steps)
        if (not $result->[0]->{'workflow_proc_state'} =~ $state_regex) {
            sleep 1;
            next;
        }
        # expected proc state reached
        return 1;
    }
    die("Timeout reached while waiting for workflow to reach state $state_regex");
}

1;
