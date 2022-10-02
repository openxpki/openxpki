package OpenXPKI::Client::UI::Response::OnException::Handler;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

has 'status_code' => (
    is => 'rw',
    isa => 'ArrayRef[Int]',
);

has 'redirect' => (
    is => 'rw',
    isa => 'Str',
);


sub is_set {
    my $self = shift;
    return $self->has_any_value;
}

__PACKAGE__->meta->make_immutable;
