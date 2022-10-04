package OpenXPKI::Client::UI::Response;
use OpenXPKI::Client::UI::Response::DTO;

# Project modules
use OpenXPKI::Client::UI::Response::Menu;
use OpenXPKI::Client::UI::Response::OnException;
use OpenXPKI::Client::UI::Response::PageInfo;
use OpenXPKI::Client::UI::Response::Redirect;
use OpenXPKI::Client::UI::Response::Refresh;
use OpenXPKI::Client::UI::Response::Sections;
use OpenXPKI::Client::UI::Response::Status;
use OpenXPKI::Client::UI::Response::User;

#
# Internal attributes
#   documentation => 'IGNORE' tells OpenXPKI::Client::UI::Response::DTORole->resolve
#   to exclude these attributes from the hash it builds.
#
has_dto 'redirect' => (
    documentation => 'IGNORE',
    class => 'OpenXPKI::Client::UI::Response::Redirect',
);

has 'raw_response' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'Any',
    predicate => 'has_raw_response',
);

#
# Items of the response hash
#   documentation => '...' tells OpenXPKI::Client::UI::Response::DTORole->resolve
#   to use the given name (not the attribute name) as hash key for this value.
#
has_dto 'infobox' => (
    documentation => 'right',
    class => 'OpenXPKI::Client::UI::Response::Sections',
);

has 'language' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'main' => (
    class => 'OpenXPKI::Client::UI::Response::Sections',
);

has_dto 'menu' => (
    documentation => 'structure',
    class => 'OpenXPKI::Client::UI::Response::Menu',
);

has_dto 'on_exception' => (
    class => 'OpenXPKI::Client::UI::Response::OnException',
);

has_dto 'page' => (
    class => 'OpenXPKI::Client::UI::Response::PageInfo',
);

has 'ping' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'refresh' => (
    class => 'OpenXPKI::Client::UI::Response::Refresh',
);

has 'rtoken' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'status' => (
    class => 'OpenXPKI::Client::UI::Response::Status',
);

has 'tenant' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'user' => (
    class => 'OpenXPKI::Client::UI::Response::User',
);

sub set_page { shift->page(OpenXPKI::Client::UI::Response::PageInfo->new(@_)) }
sub set_refresh { shift->refresh(OpenXPKI::Client::UI::Response::Refresh->new(@_)) }
sub set_user { shift->user(OpenXPKI::Client::UI::Response::User->new(@_)) }

# overrides OpenXPKI::Client::UI::Response::DTORole->is_set()
sub is_set { 1 }

__PACKAGE__->meta->make_immutable;
