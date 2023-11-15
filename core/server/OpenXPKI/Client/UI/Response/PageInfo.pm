package OpenXPKI::Client::UI::Response::PageInfo;
use OpenXPKI::Client::UI::Response::DTO;

use OpenXPKI::Client::UI::Response::Button;

has 'label' => (
    is => 'rw',
    isa => 'Str|Undef',
);

has 'shortlabel' => (
    is => 'rw',
    isa => 'Str|Undef',
);

has 'description' => (
    is => 'rw',
    isa => 'Str',
);

has 'breadcrumb' => (
    is => 'rw',
    isa => 'HashRef',
);

has 'css_class' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'className',
);

has 'buttons' => (
    is => 'rw',
    isa => 'ArrayRef[OpenXPKI::Client::UI::Response::Button]',
    default => sub { [] },
    lazy => 1,
);

# only for popups
has 'large' => (
    is => 'rw',
    isa => 'Bool',
    documentation => 'isLarge',
);

# TODO: Not used as of 2022-10-18. We keep it for future testing purposes. Set in OpenXPKI::Client::UI::Workflow->__render_from_workflow()
has 'canonical_uri' => (
    is => 'rw',
    isa => 'Str',
);

sub suppress_breadcrumb {
    my $self = shift;

    $self->breadcrumb({ suppress => 1 });
}

sub add_button {
    my $self = shift;

    push $self->buttons->@*, OpenXPKI::Client::UI::Response::Button->new(@_);

    return $self; # allows for method chaining
}

__PACKAGE__->meta->make_immutable;
