package OpenXPKI::Client::UI::Response;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

# Core modules
use Digest::SHA qw( sha1_base64 );
use List::Util qw( none all first );

# CPAN modules
use CGI 4.08 qw( -utf8 );
use JSON;
use Moose::Util qw( does_role );
use Moose::Util::TypeConstraints;

# Project modules
use OpenXPKI::i18n qw( i18nTokenizer );
use OpenXPKI::Client::UI::Response::Menu;
use OpenXPKI::Client::UI::Response::OnException;
use OpenXPKI::Client::UI::Response::PageInfo;
use OpenXPKI::Client::UI::Response::Redirect;
use OpenXPKI::Client::UI::Response::Refresh;
use OpenXPKI::Client::UI::Response::Section::Form;
use OpenXPKI::Client::UI::Response::Sections;
use OpenXPKI::Client::UI::Response::Status;
use OpenXPKI::Client::UI::Response::User;

has 'ui_result'=> (
    documentation => 'IGNORE',
    is => 'ro',
    isa => duck_type( [qw( _session __persist_status __fetch_status )] ),
    required => 1,
);

has '_redirect'=> (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Redirect',
    default => sub { OpenXPKI::Client::UI::Response::Redirect->new },
    lazy => 1,
    reader => 'redirect',
);


has 'raw_response' => (
    documentation => 'IGNORE',
    is => 'rw',
    isa => 'Any',
    predicate => 'has_raw_response',
);

has '_page'=> (
    documentation => 'page',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::PageInfo',
    default => sub { OpenXPKI::Client::UI::Response::PageInfo->new },
    lazy => 1,
    reader => 'page',
);

has '_refresh'=> (
    documentation => 'refresh',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Refresh',
    default => sub { OpenXPKI::Client::UI::Response::Refresh->new },
    lazy => 1,
    reader => 'refresh',
);

has '_status'=> (
    documentation => 'status',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Status',
    default => sub { OpenXPKI::Client::UI::Response::Status->new },
    lazy => 1,
    reader => 'status',
);

has '_user'=> (
    documentation => 'user',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::User',
    default => sub { OpenXPKI::Client::UI::Response::User->new },
    lazy => 1,
    reader => 'user',
);

has '_menu'=> (
    documentation => 'structure',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Menu',
    default => sub { OpenXPKI::Client::UI::Response::Menu->new },
    lazy => 1,
    reader => 'menu',
);

has '_on_exception'=> (
    documentation => 'on_exception',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::OnException',
    default => sub { OpenXPKI::Client::UI::Response::OnException->new },
    lazy => 1,
    reader => 'on_exception',
);

has '_main'=> (
    documentation => 'main',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Sections',
    default => sub { OpenXPKI::Client::UI::Response::Sections->new },
    lazy => 1,
    reader => 'main',
);

has '_infobox'=> (
    documentation => 'right',
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Sections',
    default => sub { OpenXPKI::Client::UI::Response::Sections->new },
    lazy => 1,
    reader => 'infobox',
);

has 'rtoken' => (
    is => 'rw',
    isa => 'Str',
);

has 'language' => (
    is => 'rw',
    isa => 'Str',
);

has 'tenant' => (
    is => 'rw',
    isa => 'Str',
);

has 'ping' => (
    is => 'rw',
    isa => 'Str',
);

sub set_page { shift->_page(OpenXPKI::Client::UI::Response::PageInfo->new(@_)) }
sub set_redirect { shift->_redirect(OpenXPKI::Client::UI::Response::Redirect->new(@_)) }
sub set_refresh { shift->_refresh(OpenXPKI::Client::UI::Response::Refresh->new(@_)) }
sub set_status { shift->_status(OpenXPKI::Client::UI::Response::Status->new(@_)) }
sub set_user { shift->_user(OpenXPKI::Client::UI::Response::User->new(@_)) }

sub new_form { my $self = shift; OpenXPKI::Client::UI::Response::Section::Form->new(@_) }
sub add_form { my $self = shift; my $form = $self->new_form(@_); $self->main->add_section($form); return $form }

sub is_set { 1 } # required by OpenXPKI::Client::UI::Response::DTORole

=head2 render_to_str

Assemble the return hash from the internal caches and return the result as a
string.

=cut
sub render_to_str {
    my $self = shift;

    my $status = $self->status->is_set ? $self->status->resolve : $self->ui_result->__fetch_status;

    #
    # A) page redirect
    #
    if ($self->redirect->is_set) {
        # Persist and append status
        if ($status) {
            my $url_param = $self->ui_result->__persist_status($status);
            $self->redirect->to($self->redirect->to . '!' . $url_param);
        }
        return encode_json({
            %{ $self->redirect->resolve },
            session_id => $self->ui_result->_session->id
        });
    }


    #
    # B) raw data
    #
    if ($self->has_raw_response) {
        return i18nTokenizer(encode_json($self->raw_response));
    }

    #
    # C) regular response
    #
    my $result = $self->resolve;

    # Dedicated data transfer objects (DTO) for complex parameters
    if ($self->page->is_set && (my $motd = $self->ui_result->_session->param('motd'))) {
        # show message of the day if we have a page section (may overwrite status)
        $self->ui_result->_session->param('motd', undef);
        $result->{status} = $motd;
    }

    $result->{session_id} = $self->ui_result->_session->id;

    return i18nTokenizer(encode_json($result));
}

__PACKAGE__->meta->make_immutable;
