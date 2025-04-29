package OpenXPKI::Client::Service::WebUI::Response::OnException;
use OpenXPKI -dto;

# Project modules
use OpenXPKI::Client::Service::WebUI::Response::OnException::Handler;

has 'handlers' => (
    is => 'rw',
    isa => 'ArrayRef[OpenXPKI::Client::Service::WebUI::Response::OnException::Handler]',
    traits => ['Array'],
    handles => {
        _add_handler => 'push',
        _no_handler => 'is_empty',
    },
    default => sub { [] }, # without default 'is_empty' would fail if no value has been set yet
    documentation => 'ROOT',
);


# overrides OpenXPKI::Client::Service::WebUI::Response::DTORole->is_set()
sub is_set { ! shift->_no_handler }

sub add_handler {
    my $self = shift;
    $self->_add_handler(OpenXPKI::Client::Service::WebUI::Response::OnException::Handler->new(@_));
    return $self; # allows for method chaining
}

__PACKAGE__->meta->make_immutable;
