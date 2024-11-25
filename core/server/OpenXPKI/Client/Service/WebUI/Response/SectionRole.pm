package OpenXPKI::Client::Service::WebUI::Response::SectionRole;
use OpenXPKI qw( -role -typeconstraints );

has 'type' => (
    is => 'rw',
    isa => enum([qw( text keyvalue grid form chart tiles )]),
);

has 'label' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has 'description' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has 'buttons' => (
    is => 'rw',
    isa => 'ArrayRef[HashRef]',
    documentation => 'content/',
);

1;
