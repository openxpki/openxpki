package OpenXPKI::Client::Service::WebUI::Response::Menu::Item;
use OpenXPKI qw( -dto -typeconstraints );

has 'label' => (
    is => 'rw',
    isa => 'Str',
);

has 'page' => (
    is => 'rw',
    isa => 'Str',
);

has 'url' => (
    is => 'rw',
    isa => 'Str',
);

has 'icon' => (
    is => 'rw',
    isa => 'Str',
);

subtype 'ArrayRefOfMenuItem', as 'ArrayRef['.__PACKAGE__.']';
coerce 'ArrayRefOfMenuItem',
    from 'ArrayRef[HashRef]',
    via {
        [ map { ref $_ eq __PACKAGE__ ? $_ : __PACKAGE__->new($_->%*) } $_->@* ]
    };
has 'entries' => (
    is => 'rw',
    isa => 'ArrayRefOfMenuItem',
    coerce => 1,
);

around BUILDARGS => sub {
    my ($orig, $class, %params) = @_;

    # map legacy attribute "key" to "page"
    my $legacy_key = delete $params{key};
    $params{page} //= $legacy_key if $legacy_key;

    return $class->$orig(%params);
};

__PACKAGE__->meta->make_immutable;
