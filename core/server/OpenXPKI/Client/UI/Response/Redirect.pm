package OpenXPKI::Client::UI::Response::Redirect;
use OpenXPKI::Client::UI::Response::DTO;

use Moose::Util::TypeConstraints qw( enum ); # PLEASE NOTE: this enables all warnings via Moose::Exporter

has 'to' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_goto',
    documentation => 'goto',
);

has 'type' => (
    is => 'rw',
    isa => enum([qw( internal external )]),
    default => 'internal',
);

sub external {
    my $self = shift;
    my $to = shift;
    $self->type('external');
    $self->to($to);
}

# overrides OpenXPKI::Client::UI::Response::DTORole->is_set()
sub is_set {
    my $self = shift;
    return $self->has_goto;
}

__PACKAGE__->meta->make_immutable;
