package OpenXPKI::Test::QA::Role::Workflows;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::QA::Role::Workflows - Moose role that extends L<OpenXPKI::Test> to
prepare the test server for workflow execution.

=cut

# CPAN modules
use Test::More;
use Test::Exception;

# Project modules
use OpenXPKI::Server::Context;
use OpenXPKI::Test::QA::Role::Workflows::CertParams;
use OpenXPKI::Serialization::Simple;


requires 'also_init';


has _last_api_result => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    default => sub { {} },
);
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

sub api_command {
    my ($self, $command, $params) = @_;

    my $result;
    lives_ok {
        $result = OpenXPKI::Server::Context::CTX('api')->$command($params);
        $self->_last_api_result($result);
    } "API command '$command'";

    return $result;
}

sub wf_activity {
    my ($self, $expected_state, $activity, $params) = @_;

    if ($expected_state) {
        is $self->_last_api_result->{WORKFLOW}->{STATE}, $expected_state, "state is '$expected_state'";
    }

    return $self->api_command(
        execute_workflow_activity => {
            ID => $self->_workflow_id,
            ACTIVITY => $activity,
            PARAMS => $params,
        }
    );
}

1;
