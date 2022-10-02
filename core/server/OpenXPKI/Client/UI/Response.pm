package OpenXPKI::Client::UI::Response;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

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
#
has 'redirect'=> (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Redirect',
    default => sub { OpenXPKI::Client::UI::Response::Redirect->new },
    lazy => 1,
);

has 'raw_response' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'Any',
    predicate => 'has_raw_response',
);

#
# Items of the response hash
#
has 'infobox'=> (
    documentation => 'right',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Sections',
    default => sub { OpenXPKI::Client::UI::Response::Sections->new },
    lazy => 1,
);

has 'language' => (
    is => 'rw',
    isa => 'Str',
);

has 'main'=> (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Sections',
    default => sub { OpenXPKI::Client::UI::Response::Sections->new },
    lazy => 1,
);

has 'menu'=> (
    documentation => 'structure',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Menu',
    default => sub { OpenXPKI::Client::UI::Response::Menu->new },
    lazy => 1,
);

has 'on_exception'=> (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::OnException',
    default => sub { OpenXPKI::Client::UI::Response::OnException->new },
    lazy => 1,
);

has 'page'=> (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::PageInfo',
    default => sub { OpenXPKI::Client::UI::Response::PageInfo->new },
    lazy => 1,
);

has 'ping' => (
    is => 'rw',
    isa => 'Str',
);

has 'refresh'=> (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Refresh',
    default => sub { OpenXPKI::Client::UI::Response::Refresh->new },
    lazy => 1,
);

has 'rtoken' => (
    is => 'rw',
    isa => 'Str',
);

has 'status'=> (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Status',
    default => sub { OpenXPKI::Client::UI::Response::Status->new },
    lazy => 1,
);

has 'tenant' => (
    is => 'rw',
    isa => 'Str',
);

has 'user'=> (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::User',
    default => sub { OpenXPKI::Client::UI::Response::User->new },
    lazy => 1,
);

sub set_page { shift->page(OpenXPKI::Client::UI::Response::PageInfo->new(@_)) }
sub set_refresh { shift->refresh(OpenXPKI::Client::UI::Response::Refresh->new(@_)) }
sub set_user { shift->user(OpenXPKI::Client::UI::Response::User->new(@_)) }

sub is_set { 1 } # required by OpenXPKI::Client::UI::Response::DTORole

__PACKAGE__->meta->make_immutable;
