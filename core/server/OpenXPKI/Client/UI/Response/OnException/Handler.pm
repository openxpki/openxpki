package OpenXPKI::Client::UI::Response::OnException::Handler;
use OpenXPKI::Client::UI::Response::DTO;

has 'status_code' => (
    is => 'rw',
    isa => 'ArrayRef[Int]',
);

has 'redirect' => (
    is => 'rw',
    isa => 'Str',
);

__PACKAGE__->meta->make_immutable;
