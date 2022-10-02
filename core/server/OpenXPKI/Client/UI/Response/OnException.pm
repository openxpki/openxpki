package OpenXPKI::Client::UI::Response::OnException;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

# Project modules
use OpenXPKI::Client::UI::Response::OnException::Handler;

has 'handlers' => (
    is => 'rw',
    isa => 'ArrayRef[OpenXPKI::Client::UI::Response::OnException::Handler]',
    traits => ['Array'],
    handles => {
        _add_handler => 'push',
        _no_handler => 'is_empty',
    },
    default => sub { [] }, # without default 'is_empty' would fail if no value has been set yet
    documentation => 'ROOT',
);


sub is_set { ! shift->_no_handler }

sub add_handler {
    my $self = shift;
    $self->_add_handler(OpenXPKI::Client::UI::Response::OnException::Handler->new(@_));
    return $self; # allows for method chaining
}

__PACKAGE__->meta->make_immutable;
