package OpenXPKI::Client::Service::WebUI::Response;
use OpenXPKI -dto;


=head1 NAME

OpenXPKI::Client::UI::Response

=head1 DESCRIPTION

This is a data transfer object encapsulating the contents of the JSON response
that will be sent to the Javascript web UI.

Most of the methods of this class are available in C<OpenXPKI::Client::Service::WebUI::Page>
and L<documented there|OpenXPKI::Client::Service::WebUI::Page/JSON RESPONSE>.

=cut

# Core modules
use MIME::Base64 qw( encode_base64 );

# CPAN modules
use Crypt::CBC;

# Project modules
use OpenXPKI::Client::Service::WebUI::Response::Menu;
use OpenXPKI::Client::Service::WebUI::Response::OnException;
use OpenXPKI::Client::Service::WebUI::Response::PageInfo;
use OpenXPKI::Client::Service::WebUI::Response::Redirect;
use OpenXPKI::Client::Service::WebUI::Response::Refresh;
use OpenXPKI::Client::Service::WebUI::Response::Sections;
use OpenXPKI::Client::Service::WebUI::Response::Status;
use OpenXPKI::Client::Service::WebUI::Response::User;

#
# Constructor parameters
#   documentation => 'IGNORE' tells OpenXPKI::Client::Service::WebUI::Response::DTORole->resolve
#   to exclude these attributes from the hash it builds.
#
has 'session_cookie' => (
    documentation => 'IGNORE',
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI::SessionCookie',
    required => 1,
);

#
# Internal attributes
#
has_dto 'redirect' => (
    documentation => 'IGNORE',
    class => 'OpenXPKI::Client::Service::WebUI::Response::Redirect',
);

has 'confined_response' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'Any',
    predicate => 'has_confined_response',
);

#
# Items of the response hash
#   documentation => '...' tells OpenXPKI::Client::Service::WebUI::Response::DTORole->resolve
#   to use the given name (not the attribute name) as hash key for this value.
#
has 'language' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'main' => (
    class => 'OpenXPKI::Client::Service::WebUI::Response::Sections',
);

has_dto 'menu' => (
    documentation => 'structure',
    class => 'OpenXPKI::Client::Service::WebUI::Response::Menu',
);

has_dto 'on_exception' => (
    class => 'OpenXPKI::Client::Service::WebUI::Response::OnException',
);

has_dto 'page' => (
    class => 'OpenXPKI::Client::Service::WebUI::Response::PageInfo',
);

has 'ping' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'refresh' => (
    class => 'OpenXPKI::Client::Service::WebUI::Response::Refresh',
);

has 'rtoken' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'status' => (
    class => 'OpenXPKI::Client::Service::WebUI::Response::Status',
);

has 'tenant' => (
    is => 'rw',
    isa => 'Str',
);

has_dto 'user' => (
    class => 'OpenXPKI::Client::Service::WebUI::Response::User',
);

has 'pki_realm' => (
    is => 'rw',
    isa => 'Str',
);

sub set_page    { shift->page   (OpenXPKI::Client::Service::WebUI::Response::PageInfo->new(@_)) }
sub set_refresh { shift->refresh(OpenXPKI::Client::Service::WebUI::Response::Refresh->new(@_)) }
sub set_user    { shift->user   (OpenXPKI::Client::Service::WebUI::Response::User->new(@_)) }

# overrides OpenXPKI::Client::Service::WebUI::Response::DTORole->is_set()
sub is_set { 1 }

__PACKAGE__->meta->make_immutable;
