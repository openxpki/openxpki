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

around 'resolve' => sub {
    my $orig = shift;
    my $self = shift;

    # convert seconds to milliseconds
    my $result = $self->$orig;
    $result->{timeout} *= 1000;

    return $result;
};

__PACKAGE__->meta->make_immutable;
