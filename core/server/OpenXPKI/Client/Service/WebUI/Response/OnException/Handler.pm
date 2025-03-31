package OpenXPKI::Client::Service::WebUI::Response::OnException::Handler;
use OpenXPKI -dto;

has 'status_code' => (
    is => 'rw',
    isa => 'ArrayRef[Int]',
);

has 'redirect' => (
    is => 'rw',
    isa => 'Str',
);

__PACKAGE__->meta->make_immutable;
