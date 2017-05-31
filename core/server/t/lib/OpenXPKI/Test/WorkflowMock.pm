package OpenXPKI::Test::WorkflowMock;
use Moose;
use utf8;

# CPAN modules
use Workflow::Context;
use Workflow::Factory qw( FACTORY );
=head1 NAME

OpenXPKI::Test::WorkflowMock - Mock object that pretends to be a workflow an just provides the context object

=cut

has context => (
    is => 'rw',
    isa => 'Workflow::Context',
    lazy => 1,
    default => sub { Workflow::Context->new() },
);

has state => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => 'INITIAL',
);

sub _factory { FACTORY }

__PACKAGE__->meta->make_immutable;
