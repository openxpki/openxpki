package OpenXPKI::Client::UI::Response::PageInfo;
use OpenXPKI::Client::UI::Response::DTO;

has 'label' => (
    is => 'rw',
    isa => 'Str|Undef',
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
    isa => 'HashRef',
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

# TODO: Not used as of 2022-10-18. We keep it for future testing purposes. Set in OpenXPKI::Client::UI::Workflow->__render_from_workflow()
has 'canonical_uri' => (
    is => 'rw',
    isa => 'Str',
);

__PACKAGE__->meta->make_immutable;
