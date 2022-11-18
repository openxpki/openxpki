package OpenXPKI::Client::UI::Response;
use OpenXPKI::Client::UI::Response::DTO;

# Core modules
use MIME::Base64 qw( encode_base64 );

# CPAN modules
use Crypt::CBC;

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
# Constructor parameters
#   documentation => 'IGNORE' tells OpenXPKI::Client::UI::Response::DTORole->resolve
#   to exclude these attributes from the hash it builds.
#
has 'session_cookie' => (
    documentation => 'IGNORE',
    is => 'ro',
    isa => 'OpenXPKI::Client::UI::SessionCookie',
    required => 1,
);

#
# Internal attributes
#
has_dto 'redirect' => (
    documentation => 'IGNORE',
    class => 'OpenXPKI::Client::UI::Response::Redirect',
);

has 'confined_response' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'Any',
    predicate => 'has_confined_response',
);

has 'raw_bytes' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'Str',
    predicate => 'has_raw_bytes',
);

has 'raw_bytes_callback' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'CodeRef',
    predicate => 'has_raw_bytes_callback',
);

# HTTP headers
has 'headers' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'ArrayRef',
    traits => ['Array'],
    handles => {
        add_header => 'push',
    }
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

=head2 get_header_str

Returns the HTTP header string containing all headers stored via L<add_header>
plus the session cookie that contains the (encrypted) session id.

=cut
sub get_header_str {
    my $self = shift;
    my $cgi = shift;

    return $cgi->header(
        @{ $self->headers },
        -cookie => $self->session_cookie->build,
    )
}

__PACKAGE__->meta->make_immutable;
