package OpenXPKI::Client::UI::Response::Refresh;
use OpenXPKI::Client::UI::Response::DTO;

has 'uri' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_href',
    documentation => 'href',
);

# in seconds
has 'timeout' => (
    is => 'rw',
    isa => 'Int',
    default => 60,
);

# overrides OpenXPKI::Client::UI::Response::DTORole->is_set()
sub is_set {
    my $self = shift;
    return $self->has_href;
}

__PACKAGE__->meta->make_immutable;
