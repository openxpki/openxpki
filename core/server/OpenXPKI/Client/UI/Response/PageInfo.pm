package OpenXPKI::Client::UI::Response::PageInfo;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

has 'label' => (
    is => 'rw',
    isa => 'Str',
);

has 'shortlabel' => (
    is => 'rw',
    isa => 'Str',
);

has 'description' => (
    is => 'rw',
    isa => 'Str',
);

has 'breadcrumb' => (
    is => 'rw',
    isa => 'ArrayRef',
);

has 'css_class' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'className',
);

has 'large' => (
    is => 'rw',
    isa => 'Bool',
    documentation => 'isLarge',
);

has 'uri' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'canonical_uri',
);

sub is_set {
    my $self = shift;
    return $self->has_any_value;
}

__PACKAGE__->meta->make_immutable;
