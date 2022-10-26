package OpenXPKI::Client::UI::Response::Status;
use OpenXPKI::Client::UI::Response::DTO;

use Moose::Util::TypeConstraints qw( enum );

has 'level' => (
    is => 'rw',
    isa => enum([qw( success info warn error )]),
    default => 'info',
);

has 'message' => (
    is => 'rw',
    isa => 'Str',
);

has 'href' => (
    is => 'rw',
    isa => 'Str',
);

has 'field_errors' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

sub info    { my $self = shift; $self->level('info');    $self->message(shift) }
sub success { my $self = shift; $self->level('success'); $self->message(shift) }
sub warn    { my $self = shift; $self->level('warn');    $self->message(shift) }
sub error   { my $self = shift; $self->level('error');   $self->message(shift) }

# overrides OpenXPKI::Client::UI::Response::DTORole->is_set()
sub is_set {
    my $self = shift;
    return $self->message || $self->is_error;
}

sub is_error {
    my $self = shift;
    return ($self->level eq 'warn' || $self->level eq 'error' || scalar @{$self->field_errors} ? 1 : 0);
}

__PACKAGE__->meta->make_immutable;
