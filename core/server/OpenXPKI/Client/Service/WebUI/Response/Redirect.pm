package OpenXPKI::Client::Service::WebUI::Response::Redirect;
use OpenXPKI qw( -dto -typeconstraints );

has 'to' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_goto',
    documentation => 'goto',
);

my $int_ext = enum([qw( internal external )]);
no Moose::Util::TypeConstraints; # otherwise sub type() will collide with our accessor "type"

has 'type' => (
    is => 'rw',
    isa => $int_ext,
    default => 'internal',
);

sub external {
    my $self = shift;
    my $to = shift;
    $self->type('external'); # evaluated in services/oxi-content.js, method #redirect()
    $self->to($to);
}

# overrides OpenXPKI::Client::Service::WebUI::Response::DTORole->is_set()
sub is_set {
    my $self = shift;
    return $self->has_goto;
}

__PACKAGE__->meta->make_immutable;
